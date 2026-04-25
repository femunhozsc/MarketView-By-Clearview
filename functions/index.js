const admin = require('firebase-admin');
const cors = require('cors');
const express = require('express');
const fs = require('fs');
const functions = require('firebase-functions');
const path = require('path');
const { FieldValue } = require('firebase-admin/firestore');

const realDateNow = Date.now.bind(Date);
let clockOffsetMs = 0;
let clockSyncPromise = null;

function findLocalServiceAccountPath() {
  const explicitPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (explicitPath && fs.existsSync(explicitPath)) {
    try {
      const data = JSON.parse(fs.readFileSync(explicitPath, 'utf8'));
      if (data.project_id && data.private_key && data.client_email) {
        return explicitPath;
      }
    } catch (error) {
      console.warn('google_credentials_ignored', error.message);
    }
  }

  const siblingPath = path.resolve(
    __dirname,
    '..',
    'admin-dashboard',
    '.secrets',
    'service-account.json',
  );
  return fs.existsSync(siblingPath) ? siblingPath : null;
}

async function ensureLocalClockSync() {
  if (!localServiceAccountPath) return;
  if (!clockSyncPromise) {
    clockSyncPromise = fetch('https://www.google.com', { method: 'HEAD' })
      .then((response) => response.headers.get('date'))
      .then((dateHeader) => {
        if (!dateHeader) return;
        clockOffsetMs = new Date(dateHeader).getTime() - realDateNow();
        Date.now = () => realDateNow() + clockOffsetMs;
      })
      .catch((error) => {
        console.warn('clock_sync_failed', error.message);
      });
  }
  await clockSyncPromise;
}

const appOptions = {
  projectId: 'marketview-by-clearview',
};
const localServiceAccountPath = findLocalServiceAccountPath();
if (localServiceAccountPath) {
  const serviceAccount = JSON.parse(
    fs.readFileSync(localServiceAccountPath, 'utf8'),
  );
  appOptions.credential = admin.credential.cert(serviceAccount);
}

admin.initializeApp(appOptions);

const db = admin.firestore();
const app = express();

app.use(express.json({ limit: '1mb' }));
app.use(
  cors({
    origin: true,
    credentials: true,
  }),
);
app.use(async (req, res, next) => {
  try {
    await ensureLocalClockSync();
    next();
  } catch (error) {
    next(error);
  }
});

function toIso(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (typeof value === 'string') return value;
  return null;
}

function numberFrom(value) {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function textFrom(value, fallback = '') {
  return typeof value === 'string' ? value : fallback;
}

function resolveRole(decodedToken) {
  if (decodedToken.admin === true || decodedToken.adminRole === 'admin') {
    return 'admin';
  }
  if (decodedToken.support === true || decodedToken.adminRole === 'suporte') {
    return 'suporte';
  }

  const allowedEmails = (process.env.ADMIN_EMAIL_ALLOWLIST || '')
    .split(',')
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);
  const email = textFrom(decodedToken.email).toLowerCase();
  return allowedEmails.includes(email) ? 'admin' : null;
}

async function requireAdmin(req, res, next) {
  try {
    const authorization = req.header('authorization') || '';
    const match = authorization.match(/^Bearer (.+)$/i);
    if (!match) {
      return res.status(401).json({ error: 'missing_token' });
    }

    const decodedToken = await admin.auth().verifyIdToken(match[1]);
    const role = resolveRole(decodedToken);
    if (!role) {
      return res.status(403).json({ error: 'admin_permission_required' });
    }

    req.admin = {
      uid: decodedToken.uid,
      email: textFrom(decodedToken.email),
      role,
    };
    return next();
  } catch (error) {
    console.error('auth_failed', error);
    return res.status(401).json({ error: 'invalid_token' });
  }
}

function requireRole(role) {
  return (req, res, next) => {
    if (req.admin.role !== role) {
      return res.status(403).json({ error: 'insufficient_role' });
    }
    return next();
  };
}

async function countQuery(query) {
  try {
    const snapshot = await query.count().get();
    return snapshot.data().count;
  } catch (error) {
    console.warn('count_failed', error.message);
    return 0;
  }
}

async function writeAudit(req, action, resourceType, resourceId, description, extra = {}) {
  await db.collection('admin_audit_logs').add({
    adminUid: req.admin.uid,
    adminEmail: req.admin.email,
    adminRole: req.admin.role,
    action,
    resourceType,
    resourceId,
    description,
    oldValue: extra.oldValue || null,
    newValue: extra.newValue || null,
    ipAddress: req.ip || '',
    userAgent: req.header('user-agent') || '',
    createdAt: FieldValue.serverTimestamp(),
  });
}

function pageParams(req) {
  const page = Math.max(1, Number.parseInt(req.query.page || '1', 10));
  const limit = Math.min(
    100,
    Math.max(1, Number.parseInt(req.query.limit || '25', 10)),
  );
  return { page, limit, offset: (page - 1) * limit };
}

function adStatus(data) {
  if (data.deletedAt || data.removedAt) return 'removed';
  if (data.soldAt || data.soldOnMarketView) return 'sold';
  return data.isActive === false ? 'paused' : 'active';
}

function mapAd(doc) {
  const data = doc.data() || {};
  const images = Array.isArray(data.images) ? data.images : [];
  return {
    id: textFrom(data.id, doc.id),
    sellerId: textFrom(data.sellerId),
    sellerName: textFrom(data.sellerName || data.storeName, 'Usuario'),
    title: textFrom(data.title, 'Anuncio sem titulo'),
    description: textFrom(data.description),
    price: numberFrom(data.price),
    category: textFrom(data.category),
    location: textFrom(data.location),
    imageUrl: textFrom(images[0]),
    status: adStatus(data),
    isActive: data.isActive !== false,
    createdAt: toIso(data.createdAt),
  };
}

function fullName(data) {
  return `${textFrom(data.firstName)} ${textFrom(data.lastName)}`.trim();
}

function userStatus(data) {
  if (data.deletedAt) return 'deleted';
  if (data.suspendedAt) return 'suspended';
  return 'active';
}

function mapUser(doc, adsCount = 0) {
  const data = doc.data() || {};
  const address = data.address || {};
  return {
    uid: textFrom(data.uid, doc.id),
    firstName: textFrom(data.firstName),
    lastName: textFrom(data.lastName),
    name: fullName(data) || textFrom(data.email, 'Usuario'),
    email: textFrom(data.email),
    phone: textFrom(data.phone),
    city: textFrom(address.city),
    state: textFrom(address.state),
    status: userStatus(data),
    createdAt: toIso(data.createdAt),
    adsCount,
  };
}

function mapChat(doc, messageCount = 0) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    buyerId: textFrom(data.buyerId),
    buyerName: textFrom(data.buyerName, 'Comprador'),
    sellerId: textFrom(data.sellerId),
    sellerName: textFrom(data.sellerName, 'Vendedor'),
    adId: textFrom(data.adId),
    adTitle: textFrom(data.adTitle),
    lastMessage: textFrom(data.lastMessage),
    lastMessageTime: toIso(data.lastMessageTime),
    status: data.closedAt ? 'closed' : data.reviewStatus ? 'review' : 'active',
    messageCount,
  };
}

function mapSupportChat(doc, messageCount = 0) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    userId: textFrom(data.userId),
    userName: textFrom(data.userName, 'Usuario'),
    userEmail: textFrom(data.userEmail),
    subject: textFrom(data.subject, 'Atendimento MarketView'),
    status: textFrom(data.status, 'open'),
    lastMessage: textFrom(data.lastMessage),
    lastMessageTime: toIso(data.lastMessageTime || data.updatedAt),
    createdAt: toIso(data.createdAt),
    closedAt: toIso(data.closedAt),
    closedByEmail: textFrom(data.closedByEmail),
    resolutionOutcome: textFrom(data.resolutionOutcome),
    resolutionFeedback: textFrom(data.resolutionFeedback),
    type: textFrom(data.type, 'support'),
    reportTargetType: textFrom(data.reportTargetType),
    reportTargetId: textFrom(data.reportTargetId),
    reportTargetTitle: textFrom(data.reportTargetTitle),
    reportTargetOwnerId: textFrom(data.reportTargetOwnerId),
    reportReason: textFrom(data.reportReason),
    reportDetails: textFrom(data.reportDetails),
    messageCount,
  };
}

function mapSupportMessage(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    senderId: textFrom(data.senderId),
    senderName: textFrom(data.senderName, 'MarketView'),
    senderRole: textFrom(data.senderRole, 'user'),
    text: textFrom(data.text),
    createdAt: toIso(data.time || data.createdAt),
  };
}

function mapMessage(doc) {
  const data = doc.data() || {};
  return {
    id: textFrom(data.id, doc.id),
    senderId: textFrom(data.senderId),
    senderName: textFrom(data.senderName || data.buyerFirstName, 'Usuario'),
    type: textFrom(data.type, 'text'),
    text: textFrom(data.text),
    createdAt: toIso(data.time || data.createdAt),
  };
}

function mapAudit(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    adminEmail: textFrom(data.adminEmail),
    action: textFrom(data.action),
    resourceType: textFrom(data.resourceType),
    resourceId: textFrom(data.resourceId),
    description: textFrom(data.description),
    createdAt: toIso(data.createdAt),
  };
}

function mapCommunityPost(doc) {
  const data = doc.data() || {};
  return {
    id: doc.id,
    authorId: textFrom(data.authorId),
    authorType: textFrom(data.authorType, 'user'),
    authorName: textFrom(data.authorName, 'Usuario'),
    authorSubtitle: textFrom(data.authorSubtitle),
    content: textFrom(data.content),
    type: textFrom(data.type, 'aviso'),
    imageUrl: textFrom(data.imageUrl),
    imageLabel: textFrom(data.imageLabel),
    storeId: textFrom(data.storeId),
    likeCount: numberFrom(data.likeCount),
    commentCount: numberFrom(data.commentCount),
    createdAt: toIso(data.createdAt),
  };
}

app.use('/admin', requireAdmin);

app.get('/admin/summary', async (req, res) => {
  const [usersTotal, adsActive, chatsTotal, pendingReports] = await Promise.all([
    countQuery(db.collection('users')),
    countQuery(db.collection('ads').where('isActive', '==', true)),
    countQuery(db.collection('chats')),
    countQuery(db.collection('review_requests').where('status', '==', 'pending')),
  ]);

  return res.json({ usersTotal, adsActive, chatsTotal, pendingReports });
});

app.get('/admin/ads', async (req, res) => {
  const { page, limit, offset } = pageParams(req);
  const baseQuery = db.collection('ads').orderBy('createdAt', 'desc');
  const [total, snapshot] = await Promise.all([
    countQuery(db.collection('ads')),
    baseQuery.offset(offset).limit(limit).get(),
  ]);

  return res.json({
    data: snapshot.docs.map(mapAd),
    pagination: { page, limit, total },
  });
});

app.patch('/admin/ads/:adId', async (req, res) => {
  const adRef = db.collection('ads').doc(req.params.adId);
  const before = await adRef.get();
  if (!before.exists) return res.status(404).json({ error: 'ad_not_found' });

  const allowedFields = [
    'title',
    'description',
    'price',
    'category',
    'location',
    'isActive',
  ];
  const patch = {};
  for (const field of allowedFields) {
    if (Object.prototype.hasOwnProperty.call(req.body, field)) {
      patch[field] = req.body[field];
    }
  }
  patch.updatedAt = FieldValue.serverTimestamp();
  patch.adminUpdatedAt = FieldValue.serverTimestamp();
  patch.adminUpdatedBy = req.admin.uid;

  await adRef.update(patch);
  const after = await adRef.get();
  await writeAudit(
    req,
    'ad_edited',
    'ad',
    req.params.adId,
    'Anuncio editado pelo painel administrativo.',
    { oldValue: before.data(), newValue: patch },
  );

  return res.json(mapAd(after));
});

app.delete('/admin/ads/:adId', requireRole('admin'), async (req, res) => {
  const adRef = db.collection('ads').doc(req.params.adId);
  const before = await adRef.get();
  if (!before.exists) return res.status(404).json({ error: 'ad_not_found' });

  const reason = textFrom(req.body && req.body.reason, 'Remocao administrativa.');
  await adRef.update({
    isActive: false,
    removedAt: FieldValue.serverTimestamp(),
    removedBy: req.admin.uid,
    removalReason: reason,
    updatedAt: FieldValue.serverTimestamp(),
  });

  await writeAudit(
    req,
    'ad_removed',
    'ad',
    req.params.adId,
    `Anuncio removido: ${reason}`,
    { oldValue: before.data(), newValue: { isActive: false, removalReason: reason } },
  );

  return res.json({ message: 'Ad removed successfully' });
});

app.get('/admin/chats', async (req, res) => {
  const { page, limit, offset } = pageParams(req);
  const baseQuery = db.collection('chats').orderBy('lastMessageTime', 'desc');
  const [total, snapshot] = await Promise.all([
    countQuery(db.collection('chats')),
    baseQuery.offset(offset).limit(limit).get(),
  ]);

  const data = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const messageCount = await countQuery(doc.ref.collection('messages'));
      return mapChat(doc, messageCount);
    }),
  );

  return res.json({
    data,
    pagination: { page, limit, total },
  });
});

app.get('/admin/chats/:chatId/messages', async (req, res) => {
  try {
    const chatRef = db.collection('chats').doc(req.params.chatId);
    const chatDoc = await chatRef.get();
    if (!chatDoc.exists) return res.status(404).json({ error: 'chat_not_found' });

    let snapshot;
    try {
      snapshot = await chatRef
        .collection('messages')
        .orderBy('time', 'asc')
        .limit(200)
        .get();
    } catch (error) {
      console.warn('chat_messages_order_failed', req.params.chatId, error.message);
      snapshot = await chatRef.collection('messages').limit(200).get();
    }
    const messages = snapshot.docs.map(mapMessage).sort((a, b) => {
      const aTime = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bTime = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return aTime - bTime;
    });
    await writeAudit(
      req,
      'chat_viewed',
      'chat',
      req.params.chatId,
      'Chat visualizado pelo painel administrativo.',
    );

    return res.json({ messages });
  } catch (error) {
    console.error('chat_messages_failed', req.params.chatId, error);
    return res.status(500).json({
      error: 'chat_messages_failed',
      detail: error.message,
    });
  }
});

app.get('/admin/support', async (req, res) => {
  const { page, limit, offset } = pageParams(req);
  const statusFilter = textFrom(req.query.status, 'open');
  const snapshot = await db
    .collection('support_chats')
    .orderBy('lastMessageTime', 'desc')
    .limit(250)
    .get();
  const filteredDocs = snapshot.docs.filter((doc) => {
    const status = textFrom((doc.data() || {}).status, 'open');
    if (statusFilter === 'closed') return status === 'closed';
    if (statusFilter === 'all') return true;
    return status !== 'closed';
  });
  const pagedDocs = filteredDocs.slice(offset, offset + limit);

  const data = await Promise.all(
    pagedDocs.map(async (doc) => {
      const messageCount = await countQuery(doc.ref.collection('messages'));
      return mapSupportChat(doc, messageCount);
    }),
  );

  return res.json({
    data,
    pagination: { page, limit, total: filteredDocs.length },
  });
});

app.get('/admin/support/dashboard', async (req, res) => {
  const snapshot = await db
    .collection('support_chats')
    .where('status', '==', 'closed')
    .limit(1000)
    .get();
  const byAdmin = new Map();
  let resolved = 0;
  let unresolved = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const adminEmail = textFrom(data.closedByEmail, 'Admin sem email');
    const adminUid = textFrom(data.closedByUid, adminEmail);
    const outcome = textFrom(data.resolutionOutcome);
    if (outcome === 'resolved') resolved += 1;
    if (outcome === 'unresolved') unresolved += 1;

    const current =
      byAdmin.get(adminUid) || {
        adminUid,
        adminEmail,
        total: 0,
        resolved: 0,
        unresolved: 0,
      };
    current.total += 1;
    if (outcome === 'resolved') current.resolved += 1;
    if (outcome === 'unresolved') current.unresolved += 1;
    byAdmin.set(adminUid, current);
  }

  return res.json({
    totalClosed: snapshot.size,
    resolved,
    unresolved,
    admins: Array.from(byAdmin.values()).sort((a, b) => b.total - a.total),
  });
});

app.get('/admin/support/:supportChatId/messages', async (req, res) => {
  try {
    const chatRef = db.collection('support_chats').doc(req.params.supportChatId);
    const chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      return res.status(404).json({ error: 'support_chat_not_found' });
    }

    let snapshot;
    try {
      snapshot = await chatRef
        .collection('messages')
        .orderBy('time', 'asc')
        .limit(300)
        .get();
    } catch (error) {
      console.warn(
        'support_messages_order_failed',
        req.params.supportChatId,
        error.message,
      );
      snapshot = await chatRef.collection('messages').limit(300).get();
    }
    const messages = snapshot.docs.map(mapSupportMessage).sort((a, b) => {
      const aTime = a.createdAt ? new Date(a.createdAt).getTime() : 0;
      const bTime = b.createdAt ? new Date(b.createdAt).getTime() : 0;
      return aTime - bTime;
    });

    await writeAudit(
      req,
      'support_chat_viewed',
      'support_chat',
      req.params.supportChatId,
      'Chat de suporte visualizado pelo painel administrativo.',
    );

    return res.json({ messages });
  } catch (error) {
    console.error('support_messages_failed', req.params.supportChatId, error);
    return res.status(500).json({
      error: 'support_messages_failed',
      detail: error.message,
    });
  }
});

app.post('/admin/support/:supportChatId/messages', async (req, res) => {
  const text = textFrom(req.body && req.body.text).trim();
  if (!text) return res.status(400).json({ error: 'message_required' });

  const chatRef = db.collection('support_chats').doc(req.params.supportChatId);
  const chatDoc = await chatRef.get();
  if (!chatDoc.exists) {
    return res.status(404).json({ error: 'support_chat_not_found' });
  }
  if (textFrom((chatDoc.data() || {}).status, 'open') === 'closed') {
    return res.status(409).json({ error: 'support_chat_closed' });
  }

  const messageRef = chatRef.collection('messages').doc();
  const batch = db.batch();
  batch.set(messageRef, {
    id: messageRef.id,
    senderId: req.admin.uid,
    senderName: req.admin.email || 'MarketView',
    senderRole: 'admin',
    text,
    time: FieldValue.serverTimestamp(),
    readBy: [req.admin.uid],
  });
  batch.set(
    chatRef,
    {
      status: 'open',
      lastMessage: text,
      lastMessageSenderRole: 'admin',
      lastMessageTime: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  await batch.commit();

  await writeAudit(
    req,
    'support_message_sent',
    'support_chat',
    req.params.supportChatId,
    'Resposta enviada pelo suporte MarketView.',
  );

  const created = await messageRef.get();
  return res.status(201).json(mapSupportMessage(created));
});

app.patch('/admin/support/:supportChatId/close', async (req, res) => {
  const outcome = textFrom(req.body && req.body.resolutionOutcome).trim();
  const feedback = textFrom(req.body && req.body.resolutionFeedback).trim();
  if (!['resolved', 'unresolved'].includes(outcome)) {
    return res.status(400).json({ error: 'invalid_resolution_outcome' });
  }
  if (!feedback) return res.status(400).json({ error: 'feedback_required' });

  const chatRef = db.collection('support_chats').doc(req.params.supportChatId);
  const before = await chatRef.get();
  if (!before.exists) {
    return res.status(404).json({ error: 'support_chat_not_found' });
  }

  await chatRef.set(
    {
      status: 'closed',
      closedAt: FieldValue.serverTimestamp(),
      closedByUid: req.admin.uid,
      closedByEmail: req.admin.email,
      resolutionOutcome: outcome,
      resolutionFeedback: feedback,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );

  await writeAudit(
    req,
    'support_chat_closed',
    'support_chat',
    req.params.supportChatId,
    `Atendimento finalizado como ${outcome}.`,
    {
      oldValue: before.data(),
      newValue: { status: 'closed', resolutionOutcome: outcome, resolutionFeedback: feedback },
    },
  );

  const after = await chatRef.get();
  return res.json(mapSupportChat(after));
});

app.get('/admin/community-posts', async (req, res) => {
  const { page, limit, offset } = pageParams(req);
  const query = db.collection('community_posts').orderBy('createdAt', 'desc');
  const [total, snapshot] = await Promise.all([
    countQuery(db.collection('community_posts')),
    query.offset(offset).limit(limit).get(),
  ]);

  return res.json({
    data: snapshot.docs.map(mapCommunityPost),
    pagination: { page, limit, total },
  });
});

app.patch('/admin/community-posts/:postId', async (req, res) => {
  const postRef = db.collection('community_posts').doc(req.params.postId);
  const before = await postRef.get();
  if (!before.exists) {
    return res.status(404).json({ error: 'community_post_not_found' });
  }

  const patch = {};
  if (Object.prototype.hasOwnProperty.call(req.body, 'content')) {
    patch.content = textFrom(req.body.content).trim();
  }
  if (Object.prototype.hasOwnProperty.call(req.body, 'type')) {
    patch.type = textFrom(req.body.type, 'aviso');
  }
  if (Object.prototype.hasOwnProperty.call(req.body, 'imageLabel')) {
    patch.imageLabel = textFrom(req.body.imageLabel);
  }
  if (!patch.content) {
    return res.status(400).json({ error: 'content_required' });
  }
  patch.adminUpdatedAt = FieldValue.serverTimestamp();
  patch.adminUpdatedBy = req.admin.uid;

  await postRef.update(patch);
  const after = await postRef.get();
  await writeAudit(
    req,
    'community_post_edited',
    'community_post',
    req.params.postId,
    'Publicacao da comunidade editada pelo painel administrativo.',
    { oldValue: before.data(), newValue: patch },
  );

  return res.json(mapCommunityPost(after));
});

app.delete('/admin/community-posts/:postId', async (req, res) => {
  const postRef = db.collection('community_posts').doc(req.params.postId);
  const before = await postRef.get();
  if (!before.exists) {
    return res.status(404).json({ error: 'community_post_not_found' });
  }

  const comments = await postRef.collection('comments').get();
  const batch = db.batch();
  for (const doc of comments.docs) {
    batch.delete(doc.ref);
  }
  batch.delete(postRef);
  await batch.commit();

  await writeAudit(
    req,
    'community_post_removed',
    'community_post',
    req.params.postId,
    'Publicacao da comunidade excluida pelo painel administrativo.',
    { oldValue: before.data() },
  );

  return res.json({ message: 'Community post removed successfully' });
});

app.get('/admin/users', async (req, res) => {
  const { page, limit, offset } = pageParams(req);
  const baseQuery = db.collection('users').orderBy('createdAt', 'desc');
  const [total, snapshot] = await Promise.all([
    countQuery(db.collection('users')),
    baseQuery.offset(offset).limit(limit).get(),
  ]);

  const data = await Promise.all(
    snapshot.docs.map(async (doc) => {
      const adsCount = await countQuery(
        db.collection('ads').where('sellerId', '==', doc.id),
      );
      return mapUser(doc, adsCount);
    }),
  );

  return res.json({
    data,
    pagination: { page, limit, total },
  });
});

app.patch('/admin/users/:userId', async (req, res) => {
  const userRef = db.collection('users').doc(req.params.userId);
  const before = await userRef.get();
  if (!before.exists) return res.status(404).json({ error: 'user_not_found' });

  const current = before.data() || {};
  const currentAddress = current.address || {};
  const patch = {};
  const authPatch = {};

  if (Object.prototype.hasOwnProperty.call(req.body, 'firstName')) {
    patch.firstName = textFrom(req.body.firstName).trim();
  }
  if (Object.prototype.hasOwnProperty.call(req.body, 'lastName')) {
    patch.lastName = textFrom(req.body.lastName).trim();
  }
  if (Object.prototype.hasOwnProperty.call(req.body, 'phone')) {
    patch.phone = textFrom(req.body.phone).trim();
  }
  if (
    Object.prototype.hasOwnProperty.call(req.body, 'city') ||
    Object.prototype.hasOwnProperty.call(req.body, 'state')
  ) {
    patch.address = {
      ...currentAddress,
      city: Object.prototype.hasOwnProperty.call(req.body, 'city')
        ? textFrom(req.body.city).trim()
        : textFrom(currentAddress.city),
      state: Object.prototype.hasOwnProperty.call(req.body, 'state')
        ? textFrom(req.body.state).trim()
        : textFrom(currentAddress.state),
    };
  }

  if (Object.prototype.hasOwnProperty.call(req.body, 'status')) {
    const status = textFrom(req.body.status).trim();
    if (!['active', 'suspended'].includes(status)) {
      return res.status(400).json({ error: 'invalid_user_status' });
    }
    const currentStatus = userStatus(current);
    if (status !== currentStatus) {
      if (status === 'suspended') {
        patch.suspendedAt = FieldValue.serverTimestamp();
        patch.suspendedBy = req.admin.uid;
        authPatch.disabled = true;
      } else {
        patch.suspendedAt = FieldValue.delete();
        patch.suspendedBy = FieldValue.delete();
        patch.deletedAt = FieldValue.delete();
        authPatch.disabled = false;
      }
    }
  }

  if (Object.keys(patch).length === 0) {
    return res.status(400).json({ error: 'empty_update' });
  }

  patch.adminUpdatedAt = FieldValue.serverTimestamp();
  patch.adminUpdatedBy = req.admin.uid;

  await userRef.set(patch, { merge: true });
  if (Object.keys(authPatch).length > 0) {
    await admin.auth().updateUser(req.params.userId, authPatch);
  }

  const after = await userRef.get();
  await writeAudit(
    req,
    'user_edited',
    'user',
    req.params.userId,
    'Usuario editado pelo painel administrativo.',
    { oldValue: before.data(), newValue: patch },
  );

  return res.json(mapUser(after));
});

app.get('/admin/activities', async (req, res) => {
  const { page, limit, offset } = pageParams(req);
  const query = db.collection('admin_audit_logs').orderBy('createdAt', 'desc');
  const [total, snapshot] = await Promise.all([
    countQuery(db.collection('admin_audit_logs')),
    query.offset(offset).limit(limit).get(),
  ]);

  return res.json({
    data: snapshot.docs.map(mapAudit),
    pagination: { page, limit, total },
  });
});

app.use((error, req, res, next) => {
  console.error('admin_api_error', error);
  if (res.headersSent) return next(error);
  return res.status(500).json({ error: 'internal_error' });
});

exports.api = functions.https.onRequest(app);
