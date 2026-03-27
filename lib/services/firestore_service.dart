import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/store_model.dart';
import '../models/ad_model.dart';
import 'cloudinary_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();

  // ── Usuários ──────────────────────────────────────────────────────────────

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return UserModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('getUser($uid) falhou: $e');
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).update(data);
  }

  // ── Favoritos ─────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(String uid, String adId, {required bool add}) async {
    await _firestore.collection('users').doc(uid).update({
      'favoriteAdIds': add
          ? FieldValue.arrayUnion([adId])
          : FieldValue.arrayRemove([adId]),
    });
  }

  Future<List<AdModel>> getFavoriteAds(List<String> adIds) async {
    if (adIds.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < adIds.length; i += 30) {
      chunks.add(adIds.sublist(i, i + 30 > adIds.length ? adIds.length : i + 30));
    }
    final results = <AdModel>[];
    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('ads')
          .where('id', whereIn: chunk)
          .get();
      results.addAll(snapshot.docs.map((d) => AdModel.fromMap(d.data())));
    }
    return results;
  }

  // ── Interesses do Usuário ─────────────────────────────────────────────────

  Future<void> trackCategoryClick(String uid, String category) async {
    await _firestore.collection('users').doc(uid).update({
      'categoryClicks.$category': FieldValue.increment(1),
    });
  }

  Future<List<String>> getUserTopCategories(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data() as Map<String, dynamic>;
    final clicks = Map<String, dynamic>.from(data['categoryClicks'] ?? {});
    if (clicks.isEmpty) return [];
    final sorted = clicks.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    return sorted.map((e) => e.key).toList();
  }

  // ── Lojas ─────────────────────────────────────────────────────────────────

  Future<String> createStore(StoreModel store) async {
    final docRef = _firestore.collection('stores').doc();
    final storeWithId = store.copyWith(id: docRef.id);
    await docRef.set(storeWithId.toMap());
    return docRef.id;
  }

  Future<StoreModel?> getStore(String storeId) async {
    if (storeId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('stores').doc(storeId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return StoreModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('getStore($storeId) falhou: $e');
    }
    return null;
  }

  Future<void> updateStore(String storeId, Map<String, dynamic> data) async {
    await _firestore.collection('stores').doc(storeId).update(data);
  }

  Future<List<StoreModel>> getStores({int limit = 15}) async {
    final snapshot = await _firestore
        .collection('stores')
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
  }

  Future<List<StoreModel>> getFeaturedStores({int limit = 15}) async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();
      final stores = snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
      stores.sort((a, b) => b.rating.compareTo(a.rating));
      return stores.take(limit).toList();
    } catch (e) {
      debugPrint('getFeaturedStores falhou: $e');
      return [];
    }
  }

  // ── Anúncios ──────────────────────────────────────────────────────────────

  Future<String> createAd(AdModel ad) async {
    final docRef = _firestore.collection('ads').doc();
    final adWithId = ad.copyWith(id: docRef.id);
    await docRef.set(adWithId.toMap());
    return docRef.id;
  }

  Future<AdModel?> getAd(String adId) async {
    if (adId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('ads').doc(adId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return AdModel.fromMap(data);
      }
    } catch (e) {
      debugPrint('getAd($adId) falhou: $e');
    }
    return null;
  }

  Future<List<AdModel>> getAds({
    String? type,
    String? category,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore.collection('ads')
          .orderBy('createdAt', descending: true);
      if (type != null) query = query.where('type', isEqualTo: type);
      if (category != null) query = query.where('category', isEqualTo: category);
      query = query.limit(limit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AdModel.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('getAds falhou, usando fallback sem filtros: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
        return snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return AdModel.fromMap(data);
        }).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> getAdsByCategory(String category, {int limit = 6}) async {
    try {
      final snapshot = await _firestore
          .collection('ads')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('getAdsByCategory($category) falhou, usando fallback: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .where('category', isEqualTo: category)
            .limit(limit)
            .get();
        final ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ads;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> getPersonalAdsByUser(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('ads')
          .where('sellerId', isEqualTo: uid)
          .where('storeId', isNull: true)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('getPersonalAdsByUser falhou, usando fallback: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .where('sellerId', isEqualTo: uid)
            .get();
        final ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ads;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> getAdsByStore(String storeId) async {
    try {
      final snapshot = await _firestore
          .collection('ads')
          .where('storeId', isEqualTo: storeId)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('getAdsByStore falhou, usando fallback: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .where('storeId', isEqualTo: storeId)
            .get();
        final ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ads;
      } catch (_) {
        return [];
      }
    }
  }

  Future<void> updateAd(String adId, Map<String, dynamic> data) async {
    await _firestore.collection('ads').doc(adId).update(data);
  }

  Future<void> deleteAd(String adId) async {
    final ad = await getAd(adId);
    if (ad != null && ad.imagePublicIds.isNotEmpty) {
      await _cloudinary.deleteImages(ad.imagePublicIds);
    }
    await _firestore.collection('ads').doc(adId).delete();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Cria ou retorna uma conversa existente entre dois usuários sobre um anúncio.
  /// Também salva o título do anúncio no documento do chat para exibição na lista.
  Future<String> getOrCreateChat(
    String buyerId,
    String sellerId,
    String adId, {
    String adTitle = '',
  }) async {
    // Validações básicas
    if (buyerId.isEmpty) {
      throw Exception('ID do comprador não pode estar vazio');
    }
    if (sellerId.isEmpty) {
      throw Exception(
        'Este anúncio não possui um vendedor válido. '
        'Não é possível iniciar um chat.',
      );
    }
    if (buyerId == sellerId) {
      throw Exception('Você não pode iniciar um chat com você mesmo.');
    }

    try {
      // Tenta encontrar conversa existente
      final snapshot = await _firestore
          .collection('chats')
          .where('buyerId', isEqualTo: buyerId)
          .where('sellerId', isEqualTo: sellerId)
          .where('adId', isEqualTo: adId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }

      // Cria nova conversa
      final docRef = _firestore.collection('chats').doc();
      await docRef.set({
        'id': docRef.id,
        'buyerId': buyerId,
        'sellerId': sellerId,
        'participants': [buyerId, sellerId],
        'adId': adId,
        'adTitle': adTitle, // salvo para exibir na lista de chats
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      });
      return docRef.id;
    } catch (e) {
      debugPrint('getOrCreateChat falhou: $e');
      rethrow;
    }
  }

  /// Envia uma mensagem em uma conversa
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    final batch = _firestore.batch();

    final msgRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(msgRef, {
      'id': msgRef.id,
      'senderId': senderId,
      'text': text,
      'time': FieldValue.serverTimestamp(),
    });

    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Stream de mensagens de uma conversa (ordenação local na tela)
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots();
  }

  /// Stream de conversas de um usuário (ordenação local na tela)
  Stream<QuerySnapshot> getUserChatsStream(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  // ── Anúncios populares / recomendados ─────────────────────────────────────

  Future<List<AdModel>> getPopularAds({int limit = 6, DocumentSnapshot? startAfter}) async {
    try {
      final fetchLimit = startAfter != null ? limit : limit * 3;
      Query query = _firestore
          .collection('ads')
          .orderBy('clickCount', descending: true)
          .limit(fetchLimit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      final ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      ads.sort((a, b) {
        final clickCmp = b.clickCount.compareTo(a.clickCount);
        if (clickCmp != 0) return clickCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return ads.take(limit).toList();
    } catch (e) {
      debugPrint('getPopularAds falhou, usando fallback por createdAt: $e');
      final snapshot = await _firestore
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> incrementAdClick(String adId) async {
    if (adId.isEmpty) return;
    try {
      await _firestore.collection('ads').doc(adId).update({
        'clickCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('incrementAdClick($adId) falhou: $e');
    }
  }

  Future<Map<String, dynamic>> getAdsByCategoryPaginated(
    String category, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('ads')
          .where('category', isEqualTo: category)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      final ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return {'ads': ads, 'lastDoc': lastDoc};
    } catch (e) {
      debugPrint('getAdsByCategoryPaginated($category) falhou, usando fallback: $e');
      try {
        Query query = _firestore
            .collection('ads')
            .where('category', isEqualTo: category)
            .limit(limit);
        if (startAfter != null) query = query.startAfterDocument(startAfter);
        final snapshot = await query.get();
        final ads = snapshot.docs
            .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        return {'ads': ads, 'lastDoc': lastDoc};
      } catch (_) {
        return {'ads': <AdModel>[], 'lastDoc': null};
      }
    }
  }

  Future<Map<String, dynamic>> getRecommendedAdsPaginated(
    List<String> topCategories, {
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      if (topCategories.isEmpty) {
        Query query = _firestore
            .collection('ads')
            .orderBy('clickCount', descending: true)
            .limit(limit);
        if (startAfter != null) query = query.startAfterDocument(startAfter);
        final snapshot = await query.get();
        final ads = snapshot.docs
            .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        return {'ads': ads, 'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null};
      }
      final cats = topCategories.take(3).toList();
      Query query = _firestore
          .collection('ads')
          .where('category', whereIn: cats)
          .orderBy('createdAt', descending: true)
          .limit(limit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      final ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      return {'ads': ads, 'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null};
    } catch (e) {
      debugPrint('getRecommendedAdsPaginated falhou, usando fallback: $e');
      final snapshot = await _firestore
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      final ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      return {'ads': ads, 'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null};
    }
  }

  Future<List<StoreModel>> getAllStores() async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();
      final stores = snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
      stores.sort((a, b) => b.rating.compareTo(a.rating));
      return stores;
    } catch (e) {
      debugPrint('getAllStores falhou: $e');
      return [];
    }
  }
}