export type AdminRole = 'admin' | 'suporte';

export type AdminUser = {
  uid: string;
  email: string;
  name: string;
  role: AdminRole;
};

export type PageResponse<T> = {
  data: T[];
  pagination: {
    page: number;
    limit: number;
    total: number;
  };
};

export type DashboardSummary = {
  usersTotal: number;
  adsActive: number;
  chatsTotal: number;
  pendingReports: number;
};

export type ChatSummary = {
  id: string;
  buyerId: string;
  buyerName: string;
  sellerId: string;
  sellerName: string;
  adId: string;
  adTitle: string;
  lastMessage: string;
  lastMessageTime: string | null;
  status: 'active' | 'review' | 'closed';
  messageCount: number;
};

export type ChatMessage = {
  id: string;
  senderId: string;
  senderName: string;
  type: 'text' | 'offer' | string;
  text: string;
  createdAt: string | null;
};

export type SupportChatSummary = {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  subject: string;
  status: 'open' | 'closed' | string;
  lastMessage: string;
  lastMessageTime: string | null;
  createdAt: string | null;
  closedAt: string | null;
  closedByEmail: string;
  resolutionOutcome: 'resolved' | 'unresolved' | string;
  resolutionFeedback: string;
  type: 'support' | 'report' | string;
  reportTargetType: 'ad' | 'community_post' | string;
  reportTargetId: string;
  reportTargetTitle: string;
  reportTargetOwnerId: string;
  reportReason: string;
  reportDetails: string;
  messageCount: number;
};

export type SupportMessage = {
  id: string;
  senderId: string;
  senderName: string;
  senderRole: 'user' | 'admin' | string;
  text: string;
  createdAt: string | null;
};

export type SupportDashboardAdmin = {
  adminUid: string;
  adminEmail: string;
  total: number;
  resolved: number;
  unresolved: number;
};

export type SupportDashboard = {
  totalClosed: number;
  resolved: number;
  unresolved: number;
  admins: SupportDashboardAdmin[];
};

export type AdStatus = 'active' | 'paused' | 'removed' | 'sold';

export type AdSummary = {
  id: string;
  sellerId: string;
  sellerName: string;
  title: string;
  description: string;
  price: number;
  category: string;
  location: string;
  imageUrl: string;
  status: AdStatus;
  isActive: boolean;
  createdAt: string | null;
};

export type UserSummary = {
  uid: string;
  firstName: string;
  lastName: string;
  name: string;
  email: string;
  phone: string;
  city: string;
  state: string;
  status: 'active' | 'suspended' | 'deleted';
  createdAt: string | null;
  adsCount: number;
};

export type AuditLog = {
  id: string;
  adminEmail: string;
  action: string;
  resourceType: string;
  resourceId: string;
  description: string;
  createdAt: string | null;
};

export type CommunityPostSummary = {
  id: string;
  authorId: string;
  authorType: 'user' | 'store' | string;
  authorName: string;
  authorSubtitle: string;
  content: string;
  type: 'aviso' | 'flyer' | 'promocao' | string;
  imageUrl: string;
  imageLabel: string;
  storeId: string;
  likeCount: number;
  commentCount: number;
  createdAt: string | null;
};
