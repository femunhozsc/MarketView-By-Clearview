import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/community_post_model.dart';
import '../models/user_model.dart';
import '../models/store_model.dart';
import '../models/ad_model.dart';
import 'cloudinary_service.dart';
import 'storage_service.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinary = CloudinaryService();
  final StorageService _storage = StorageService();
  static const int _userSearchBatchSize = 120;
  static const int _userSearchMaxPages = 5;

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

    final shouldSyncDisplayData = data.containsKey('firstName') ||
        data.containsKey('lastName') ||
        data.containsKey('profilePhoto');
    if (!shouldSyncDisplayData) return;

    final refreshedUser = await getUser(uid);
    if (refreshedUser == null) return;

    final personalAds = await getPersonalAdsByUser(uid);
    final storeAds = await _getStoreAdsBySeller(uid);
    if (personalAds.isEmpty && storeAds.isEmpty) return;

    final batch = _firestore.batch();
    for (final ad in personalAds) {
      batch.update(
        _firestore.collection('ads').doc(ad.id),
        {
          'sellerName': refreshedUser.fullName,
          'sellerAvatar': refreshedUser.profilePhoto ?? '',
        },
      );
    }

    for (final ad in storeAds) {
      batch.update(
        _firestore.collection('ads').doc(ad.id),
        {
          'sellerUserName': refreshedUser.fullName,
          'sellerUserAvatar': refreshedUser.profilePhoto ?? '',
        },
      );
    }

    await batch.commit();
  }

  Future<void> addStoreToUser(String uid, String storeId) async {
    final user = await getUser(uid);
    if (user == null) return;

    final updatedStoreIds = {...user.storeIds, storeId}.toList();
    await updateUser(uid, {
      'hasStore': updatedStoreIds.isNotEmpty,
      'storeId': user.primaryStoreId ?? storeId,
      'storeIds': updatedStoreIds,
    });
  }

  Future<void> removeStoreFromUser(String uid, String storeId) async {
    final user = await getUser(uid);
    if (user == null) return;

    final updatedStoreIds =
        user.storeIds.where((existingId) => existingId != storeId).toList();
    await updateUser(uid, {
      'hasStore': updatedStoreIds.isNotEmpty,
      'storeId': updatedStoreIds.isNotEmpty ? updatedStoreIds.first : null,
      'storeIds': updatedStoreIds,
    });
  }

  Future<void> updateUserSearchArea(
    String uid, {
    required AddressModel address,
    required int searchRadius,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'address': address.toMap(),
      'searchRadius': searchRadius,
    });
  }

  Future<void> deleteUserAccountData(String uid) async {
    final user = await getUser(uid);
    if (user == null) return;

    final ownedStores = (await getStoresForUser(uid))
        .where((store) => store.ownerId == uid)
        .toList();
    for (final store in ownedStores) {
      await deleteStore(storeId: store.id, actingUserId: uid);
    }

    final remainingStores = await getStoresForUser(uid);
    for (final store in remainingStores) {
      if (store.ownerId == uid) continue;
      await removeStoreMember(
        storeId: store.id,
        actingUserId: store.ownerId,
        memberUserId: uid,
      );
    }

    final personalAds = await getPersonalAdsByUser(uid);
    for (final ad in personalAds) {
      await deleteAd(ad.id);
    }

    await _deleteChatsForUser(uid);
    await _deleteReviewsForUser(uid);
    await _removeFollowerReferences(uid);

    final profilePhoto = user.profilePhoto;
    if (profilePhoto != null && profilePhoto.trim().isNotEmpty) {
      final deletedFromCloudinary =
          await _cloudinary.deleteImageByUrl(profilePhoto);
      if (!deletedFromCloudinary &&
          !await _storage.deleteFileByUrl(profilePhoto)) {
        await _queueCleanupFailure(
          entityType: 'user',
          entityId: uid,
          assetUrl: profilePhoto,
        );
      }
    }

    final bannerPhoto = user.bannerPhoto;
    if (bannerPhoto != null && bannerPhoto.trim().isNotEmpty) {
      final deletedFromCloudinary =
          await _cloudinary.deleteImageByUrl(bannerPhoto);
      if (!deletedFromCloudinary &&
          !await _storage.deleteFileByUrl(bannerPhoto)) {
        await _queueCleanupFailure(
          entityType: 'user',
          entityId: uid,
          assetUrl: bannerPhoto,
        );
      }
    }

    await _firestore.collection('users').doc(uid).delete();
  }

  // ── Favoritos ─────────────────────────────────────────────────────────────

  Future<void> toggleFavorite(String uid, String adId,
      {required bool add}) async {
    await _firestore.collection('users').doc(uid).update({
      'favoriteAdIds':
          add ? FieldValue.arrayUnion([adId]) : FieldValue.arrayRemove([adId]),
    });
  }

  Future<List<AdModel>> getFavoriteAds(List<String> adIds) async {
    if (adIds.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < adIds.length; i += 30) {
      chunks
          .add(adIds.sublist(i, i + 30 > adIds.length ? adIds.length : i + 30));
    }
    final results = <AdModel>[];
    for (final chunk in chunks) {
      final snapshot =
          await _firestore.collection('ads').where('id', whereIn: chunk).get();
      results.addAll(snapshot.docs.map((d) => AdModel.fromMap(d.data())));
    }
    return results;
  }

  Future<void> toggleFavoriteStore(
    String uid,
    String storeId, {
    required bool add,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'favoriteStoreIds': add
          ? FieldValue.arrayUnion([storeId])
          : FieldValue.arrayRemove([storeId]),
    });
  }

  Future<List<StoreModel>> getFavoriteStores(List<String> storeIds) async {
    if (storeIds.isEmpty) return [];
    final chunks = <List<String>>[];
    for (var i = 0; i < storeIds.length; i += 30) {
      chunks.add(
        storeIds.sublist(
          i,
          i + 30 > storeIds.length ? storeIds.length : i + 30,
        ),
      );
    }

    final results = <StoreModel>[];
    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('stores')
          .where('id', whereIn: chunk)
          .get();
      results.addAll(snapshot.docs.map((d) => StoreModel.fromMap(d.data())));
    }

    results.sort(
      (a, b) => storeIds.indexOf(a.id).compareTo(storeIds.indexOf(b.id)),
    );
    return results;
  }

  Future<void> toggleFollowSeller(
    String uid,
    String sellerId, {
    required bool add,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'followingSellerIds': add
          ? FieldValue.arrayUnion([sellerId])
          : FieldValue.arrayRemove([sellerId]),
    });
  }

  Future<void> trackRecentlyViewedAd(String uid, String adId) async {
    final userRef = _firestore.collection('users').doc(uid);
    final doc = await userRef.get();
    final current = List<String>.from(doc.data()?['recentlyViewedAdIds'] ?? []);
    current.remove(adId);
    current.insert(0, adId);
    await userRef.update({'recentlyViewedAdIds': current.take(50).toList()});
  }

  Future<void> togglePinnedChat(
    String uid,
    String chatId, {
    required bool add,
  }) async {
    await _firestore.collection('users').doc(uid).update({
      'pinnedChatIds': add
          ? FieldValue.arrayUnion([chatId])
          : FieldValue.arrayRemove([chatId]),
    });
  }

  Future<List<AdModel>> getAdsByIds(List<String> adIds) async {
    if (adIds.isEmpty) return [];
    final results = <AdModel>[];
    for (var i = 0; i < adIds.length; i += 10) {
      final chunk =
          adIds.sublist(i, i + 10 > adIds.length ? adIds.length : i + 10);
      final snapshot =
          await _firestore.collection('ads').where('id', whereIn: chunk).get();
      results.addAll(snapshot.docs.map((d) => AdModel.fromMap(d.data())));
    }
    results.sort((a, b) => adIds.indexOf(a.id).compareTo(adIds.indexOf(b.id)));
    return results;
  }

  DateTime _dateTimeFromDynamic(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<Map<String, dynamic>>> getReviewsForUser(String userId) async {
    if (userId.isEmpty) return [];

    final targetSnapshot = await _firestore
        .collection('reviews')
        .where('targetIds', arrayContains: userId)
        .get();
    final legacySnapshot = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .get();

    final merged = <String, Map<String, dynamic>>{};
    for (final doc in [...targetSnapshot.docs, ...legacySnapshot.docs]) {
      merged[doc.id] = {'id': doc.id, ...doc.data()};
    }

    final reviews = merged.values.toList();
    reviews.sort(
      (a, b) => _dateTimeFromDynamic(
        b['createdAt'],
      ).compareTo(_dateTimeFromDynamic(a['createdAt'])),
    );
    return reviews;
  }

  Future<void> replyToReview(String reviewId, String response) async {
    await _firestore.collection('reviews').doc(reviewId).update({
      'response': response,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<Map<String, dynamic>>> getPendingReviewRequests(
    String buyerId,
  ) async {
    if (buyerId.isEmpty) return [];

    final snapshot = await _firestore
        .collection('review_requests')
        .where('buyerId', isEqualTo: buyerId)
        .where('status', isEqualTo: 'pending')
        .get();

    final requests =
        snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    requests.sort(
      (a, b) => _dateTimeFromDynamic(b['soldAt']).compareTo(
        _dateTimeFromDynamic(a['soldAt']),
      ),
    );
    return requests;
  }

  Future<void> submitSaleReview({
    required String reviewRequestId,
    required String reviewerId,
    required String reviewerName,
    required int rating,
    List<String> strengths = const [],
    String comment = '',
    String? reviewerAvatar,
  }) async {
    final requestRef =
        _firestore.collection('review_requests').doc(reviewRequestId);
    final requestDoc = await requestRef.get();
    if (!requestDoc.exists) {
      throw Exception('Pedido de avaliação não encontrado.');
    }

    final request = requestDoc.data() as Map<String, dynamic>;
    if ((request['buyerId'] as String? ?? '') != reviewerId) {
      throw Exception('Esta avaliação não pertence a esse comprador.');
    }
    if ((request['status'] as String? ?? '') != 'pending') {
      return;
    }

    final sellerId = request['sellerId'] as String? ?? '';
    final shouldAffectStore = request['affectsStoreRating'] == true ||
        ((request['storeId'] as String? ?? '').trim().isNotEmpty &&
            (request['storeName'] as String? ?? '').trim().isNotEmpty &&
            (request['sellerName'] as String? ?? '').trim() ==
                (request['storeName'] as String? ?? '').trim());
    final storeId =
        shouldAffectStore ? (request['storeId'] as String? ?? '') : '';
    final targetIds = <String>[
      if (sellerId.isNotEmpty) sellerId,
      if (storeId.isNotEmpty) storeId,
    ];

    final reviewRef = _firestore.collection('reviews').doc(reviewRequestId);
    final batch = _firestore.batch();
    batch.set(reviewRef, {
      'id': reviewRef.id,
      'saleRequestId': reviewRequestId,
      'revieweeId': sellerId,
      'sellerId': sellerId,
      'sellerName': request['sellerName'] ?? '',
      'storeId': storeId,
      'storeName': request['storeName'] ?? '',
      'reviewerId': reviewerId,
      'authorName': reviewerName,
      'authorAvatar': reviewerAvatar ?? '',
      'rating': rating,
      'strengths': strengths,
      'comment': comment,
      'response': '',
      'targetIds': targetIds,
      'adId': request['adId'] ?? '',
      'adTitle': request['adTitle'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(requestRef, {
      'status': 'completed',
      'reviewId': reviewRef.id,
      'completedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();

    if (storeId.isNotEmpty) {
      await _refreshStoreReviewSummary(storeId);
    }
  }

  Future<void> _refreshStoreReviewSummary(String storeId) async {
    if (storeId.isEmpty) return;

    final reviews = await getReviewsForUser(storeId);
    final totalReviews = reviews.length;
    final averageRating = totalReviews == 0
        ? 0.0
        : reviews.fold<double>(
              0,
              (total, review) =>
                  total + ((review['rating'] as num?)?.toDouble() ?? 0),
            ) /
            totalReviews;

    await updateStore(storeId, {
      'rating': averageRating,
      'totalReviews': totalReviews,
    });
  }

  Future<List<UserModel>> getFollowersOfSeller(String sellerId) async {
    final snapshot = await _firestore
        .collection('users')
        .where('followingSellerIds', arrayContains: sellerId)
        .get();
    return snapshot.docs.map((d) => UserModel.fromMap(d.data())).toList();
  }

  Future<List<UserModel>> getUsersByIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final results = <UserModel>[];
    for (var i = 0; i < userIds.length; i += 10) {
      final chunk =
          userIds.sublist(i, i + 10 > userIds.length ? userIds.length : i + 10);
      final snapshot = await _firestore
          .collection('users')
          .where('uid', whereIn: chunk)
          .get();
      results.addAll(snapshot.docs.map((d) => UserModel.fromMap(d.data())));
    }
    results.sort(
        (a, b) => userIds.indexOf(a.uid).compareTo(userIds.indexOf(b.uid)));
    return results;
  }

  Future<List<UserModel>> searchUsersByName(
    String query, {
    int limit = 3,
  }) async {
    final normalizedQuery = AdModel.normalizeValue(query).trim();
    if (normalizedQuery.isEmpty) return [];

    try {
      final queryTerms = normalizedQuery
          .split(RegExp(r'[^a-z0-9]+'))
          .where((term) => term.isNotEmpty)
          .toList(growable: false);
      final rankedByUserId = <String, MapEntry<UserModel, int>>{};
      DocumentSnapshot<Map<String, dynamic>>? lastDoc;

      for (var page = 0; page < _userSearchMaxPages; page++) {
        var firestoreQuery = _firestore
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(_userSearchBatchSize);
        if (lastDoc != null) {
          firestoreQuery = firestoreQuery.startAfterDocument(lastDoc);
        }

        final snapshot = await firestoreQuery.get();
        if (snapshot.docs.isEmpty) break;

        for (final doc in snapshot.docs) {
          final user = UserModel.fromMap(doc.data());
          final fullName = AdModel.normalizeValue(user.fullName);
          final firstName = AdModel.normalizeValue(user.firstName);
          final lastName = AdModel.normalizeValue(user.lastName);
          final city = AdModel.normalizeValue(user.address.city);
          final state = AdModel.normalizeValue(user.address.state);

          var score = 0;
          if (fullName == normalizedQuery) score += 220;
          if (firstName == normalizedQuery || lastName == normalizedQuery) {
            score += 180;
          }
          if (fullName.startsWith(normalizedQuery)) score += 160;
          if (firstName.startsWith(normalizedQuery)) score += 110;
          if (lastName.startsWith(normalizedQuery)) score += 90;
          if (fullName.contains(normalizedQuery)) score += 100;
          if (city.contains(normalizedQuery) ||
              state.contains(normalizedQuery)) {
            score += 28;
          }

          for (final term in queryTerms) {
            if (fullName.contains(term)) score += 22;
            if (firstName.contains(term)) score += 18;
            if (lastName.contains(term)) score += 14;
            if (city.contains(term) || state.contains(term)) score += 6;
          }

          if (score <= 0 || user.uid.trim().isEmpty) continue;

          final previous = rankedByUserId[user.uid];
          if (previous == null || score > previous.value) {
            rankedByUserId[user.uid] = MapEntry(user, score);
          }
        }

        lastDoc = snapshot.docs.last;
        if (snapshot.docs.length < _userSearchBatchSize &&
            rankedByUserId.length >= limit) {
          break;
        }
      }

      final ranked = rankedByUserId.values.toList()
        ..sort((a, b) {
          final scoreCompare = b.value.compareTo(a.value);
          if (scoreCompare != 0) return scoreCompare;
          return b.key.createdAt.compareTo(a.key.createdAt);
        });

      return ranked.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      debugPrint('searchUsersByName($query) falhou: $e');
      return [];
    }
  }

  Future<List<StoreModel>> searchStoresByName(
    String query, {
    int limit = 3,
  }) async {
    final normalizedQuery = AdModel.normalizeValue(query).trim();
    if (normalizedQuery.isEmpty) return [];

    try {
      final queryTerms = normalizedQuery
          .split(RegExp(r'[^a-z0-9]+'))
          .where((term) => term.isNotEmpty)
          .toList(growable: false);
      final stores = await getAllStores();
      final ranked = <MapEntry<StoreModel, int>>[];

      for (final store in stores) {
        final name = AdModel.normalizeValue(store.name);
        final category = AdModel.normalizeValue(store.category);
        final description = AdModel.normalizeValue(store.description);
        final ownerName = AdModel.normalizeValue(store.ownerName);
        final accessUsername = AdModel.normalizeValue(store.accessUsername);
        final city = AdModel.normalizeValue(store.address.city);
        final state = AdModel.normalizeValue(store.address.state);

        var score = 0;
        if (name == normalizedQuery) score += 240;
        if (name.startsWith(normalizedQuery)) score += 180;
        if (name.contains(normalizedQuery)) score += 120;
        if (accessUsername.startsWith(normalizedQuery)) score += 110;
        if (accessUsername.contains(normalizedQuery)) score += 90;
        if (category.contains(normalizedQuery)) score += 52;
        if (ownerName.contains(normalizedQuery)) score += 32;
        if (description.contains(normalizedQuery)) score += 24;
        if (city.contains(normalizedQuery) || state.contains(normalizedQuery)) {
          score += 18;
        }

        for (final term in queryTerms) {
          if (name.contains(term)) score += 28;
          if (category.contains(term)) score += 18;
          if (description.contains(term)) score += 10;
          if (ownerName.contains(term) || accessUsername.contains(term)) {
            score += 10;
          }
          if (city.contains(term) || state.contains(term)) score += 4;
        }

        if (score > 0) {
          ranked.add(MapEntry(store, score));
        }
      }

      ranked.sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;

        final ratingCompare = b.key.rating.compareTo(a.key.rating);
        if (ratingCompare != 0) return ratingCompare;

        final reviewsCompare = b.key.totalReviews.compareTo(a.key.totalReviews);
        if (reviewsCompare != 0) return reviewsCompare;

        return b.key.createdAt.compareTo(a.key.createdAt);
      });

      return ranked.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      debugPrint('searchStoresByName($query) falhou: $e');
      return [];
    }
  }

  Future<List<AdModel>> searchAds(
    String query, {
    int limit = 40,
    bool includeInactive = false,
  }) async {
    final normalizedQuery = AdModel.normalizeValue(query).trim();
    if (normalizedQuery.isEmpty) return [];

    try {
      final queryTerms = normalizedQuery
          .split(RegExp(r'[^a-z0-9]+'))
          .where((term) => term.isNotEmpty)
          .toList(growable: false);
      final snapshot = await _firestore
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(limit * 3)
          .get();

      final ranked = <MapEntry<AdModel, int>>[];
      for (final doc in snapshot.docs) {
        final ad = AdModel.fromMap(doc.data());
        if (!includeInactive && !ad.isActive) continue;
        if (ad.intent != AdModel.intentSell) continue;

        final title = AdModel.normalizeValue(ad.title);
        final category = AdModel.normalizeValue(ad.category);
        final categoryType =
            AdModel.normalizeValue(ad.displayCategoryTypeLabel);
        final description = AdModel.normalizeValue(ad.description);
        final sellerName = AdModel.normalizeValue(ad.sellerName);
        final storeName = AdModel.normalizeValue(ad.storeName ?? '');

        var score = 0;
        if (title == normalizedQuery) score += 260;
        if (title.startsWith(normalizedQuery)) score += 170;
        if (title.contains(normalizedQuery)) score += 120;
        if (category.contains(normalizedQuery)) score += 60;
        if (categoryType.contains(normalizedQuery)) score += 52;
        if (description.contains(normalizedQuery)) score += 26;
        if (sellerName.contains(normalizedQuery) ||
            storeName.contains(normalizedQuery)) {
          score += 22;
        }

        for (final term in queryTerms) {
          if (title.contains(term)) score += 24;
          if (category.contains(term) || categoryType.contains(term)) {
            score += 15;
          }
          if (description.contains(term)) score += 6;
          if (sellerName.contains(term) || storeName.contains(term)) {
            score += 5;
          }
        }

        for (final attribute in ad.customAttributes) {
          final label = AdModel.normalizeValue(attribute.label);
          final value = AdModel.normalizeValue(attribute.value);
          if (label.contains(normalizedQuery) ||
              value.contains(normalizedQuery)) {
            score += 10;
          }
        }

        if (score > 0) {
          ranked.add(MapEntry(ad, score));
        }
      }

      ranked.sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;
        return b.key.createdAt.compareTo(a.key.createdAt);
      });

      return ranked.take(limit).map((entry) => entry.key).toList();
    } catch (e) {
      debugPrint('searchAds($query) falhou: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getSalesInsights(String userId,
      {String? storeId}) async {
    final personalAds = await getPersonalAdsByUser(userId);
    final storeAds =
        storeId == null ? <AdModel>[] : await getAdsByStore(storeId);
    final ads = [...personalAds, ...storeAds];
    final totalClicks =
        ads.fold<int>(0, (runningTotal, ad) => runningTotal + ad.clickCount);
    final totalAds = ads.length;
    final avgClicks = totalAds == 0 ? 0.0 : totalClicks / totalAds;
    final mostViewed = [...ads]
      ..sort((a, b) => b.clickCount.compareTo(a.clickCount));

    return {
      'totalAds': totalAds,
      'totalClicks': totalClicks,
      'averageClicks': avgClicks,
      'mostViewed': mostViewed.take(5).toList(),
    };
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

  Future<List<String>> getTrendingCategories({
    int limit = 6,
    String? intent,
  }) async {
    try {
      Query query = _firestore.collection('ads');

      final snapshot =
          await query.orderBy('clickCount', descending: true).limit(120).get();

      final categoryScores = <String, int>{};
      for (final doc in snapshot.docs) {
        final ad = AdModel.fromMap(doc.data() as Map<String, dynamic>);
        if (intent != null && ad.intent != intent) continue;

        final resolvedCategory =
            AdModel.resolveCategoryValue(ad.category).trim();
        if (resolvedCategory.isEmpty) continue;

        final currentScore = categoryScores[resolvedCategory] ?? 0;
        final engagementScore = ad.clickCount > 0 ? ad.clickCount : 1;
        categoryScores[resolvedCategory] = currentScore + engagementScore;
      }

      final rankedCategories = categoryScores.entries.toList()
        ..sort((a, b) {
          final byScore = b.value.compareTo(a.value);
          if (byScore != 0) return byScore;
          return a.key.compareTo(b.key);
        });

      return rankedCategories
          .map((entry) => entry.key)
          .take(limit)
          .toList(growable: false);
    } catch (e) {
      debugPrint('getTrendingCategories falhou: $e');
      return [];
    }
  }

  // ── Lojas ─────────────────────────────────────────────────────────────────

  Future<String> createStore(StoreModel store) async {
    final docRef = _firestore.collection('stores').doc();
    final accessUsername = await _generateUniqueStoreUsername(store.name);
    final ownerMember = StoreMember(
      userId: store.ownerId,
      name: store.ownerName,
      role: StoreMemberRole.admin,
      joinedAt: DateTime.now(),
    );
    final storeWithId = store.copyWith(
      id: docRef.id,
      accessUsername: accessUsername,
      memberUserIds: [store.ownerId],
      adminUserIds: [store.ownerId],
      members: [ownerMember],
    );
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

  Future<StoreModel?> updateStoreProfile({
    required String storeId,
    required Map<String, dynamic> data,
  }) async {
    await updateStore(storeId, data);
    final refreshedStore = await getStore(storeId);
    if (refreshedStore == null) return null;

    final ads = await getAdsByStore(storeId);
    if (ads.isNotEmpty) {
      final batch = _firestore.batch();
      for (final ad in ads) {
        batch.update(
          _firestore.collection('ads').doc(ad.id),
          {
            'sellerName': refreshedStore.name,
            'sellerAvatar': refreshedStore.logo ?? '',
            'storeName': refreshedStore.name,
            'storeLogo': refreshedStore.logo ?? '',
          },
        );
      }
      await batch.commit();
    }

    return refreshedStore;
  }

  Future<List<StoreModel>> getStoresForUser(String uid) async {
    if (uid.isEmpty) return [];
    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('memberUserIds', arrayContains: uid)
          .get();
      final stores =
          snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
      stores
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return stores;
    } catch (e) {
      debugPrint('getStoresForUser falhou: $e');
      return [];
    }
  }

  Stream<List<CommunityPostModel>> streamCommunityPosts({int limit = 60}) {
    return _firestore
        .collection('community_posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommunityPostModel.fromMap(doc.data()))
              .toList(growable: false),
        );
  }

  Stream<List<CommunityCommentModel>> streamCommunityComments(String postId) {
    if (postId.trim().isEmpty) {
      return const Stream<List<CommunityCommentModel>>.empty();
    }

    return _firestore
        .collection('community_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CommunityCommentModel.fromMap(doc.data()))
              .toList(growable: false),
        );
  }

  Future<void> createCommunityPost(CommunityPostModel post) async {
    await _firestore
        .collection('community_posts')
        .doc(post.id)
        .set(post.toMap(), SetOptions(merge: true));
  }

  Future<void> toggleCommunityPostLike({
    required String postId,
    required String userId,
  }) async {
    if (postId.trim().isEmpty || userId.trim().isEmpty) return;

    final postRef = _firestore.collection('community_posts').doc(postId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final likeUserIds =
          List<String>.from(data['likeUserIds'] ?? const <String>[]);
      final alreadyLiked = likeUserIds.contains(userId);

      if (alreadyLiked) {
        likeUserIds.remove(userId);
      } else {
        likeUserIds.add(userId);
      }

      transaction.update(postRef, {
        'likeUserIds': likeUserIds,
        'likeCount': likeUserIds.length,
      });
    });
  }

  Future<void> addCommunityComment(CommunityCommentModel comment) async {
    if (comment.postId.trim().isEmpty || comment.id.trim().isEmpty) return;

    final postRef =
        _firestore.collection('community_posts').doc(comment.postId);
    final commentRef = postRef.collection('comments').doc(comment.id);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) {
        throw Exception('Publicacao nao encontrada.');
      }

      final data = snapshot.data() as Map<String, dynamic>;
      final currentCount = (data['commentCount'] as num?)?.toInt() ?? 0;

      transaction.set(commentRef, comment.toMap());
      transaction.update(postRef, {
        'commentCount': currentCount + 1,
      });
    });
  }

  Future<void> deleteCommunityPost(String postId) async {
    if (postId.trim().isEmpty) return;

    final postRef = _firestore.collection('community_posts').doc(postId);
    final snapshot = await postRef.get();
    if (!snapshot.exists) return;

    final post = CommunityPostModel.fromMap(snapshot.data()!);
    if (post.imageUrl?.trim().isNotEmpty ?? false) {
      final imageUrl = post.imageUrl!.trim();
      final deletedFromCloudinary =
          await _cloudinary.deleteImageByUrl(imageUrl);
      if (!deletedFromCloudinary && !await _storage.deleteFileByUrl(imageUrl)) {
        await _queueCleanupFailure(
          entityType: 'community_post',
          entityId: postId,
          assetUrl: imageUrl,
        );
      }
    }

    final comments = await postRef.collection('comments').get();
    for (final doc in comments.docs) {
      await doc.reference.delete();
    }

    await postRef.delete();
  }

  Future<StoreAccessInvite> generateStoreInvite({
    required String storeId,
    required String adminUserId,
  }) async {
    final store = await getStore(storeId);
    if (store == null) {
      throw Exception('Loja não encontrada.');
    }
    if (!store.isAdmin(adminUserId)) {
      throw Exception('Apenas administradores podem gerar códigos.');
    }

    final invite = StoreAccessInvite(
      username: store.accessUsername,
      code: _generateAccessCode(),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
      createdByUserId: adminUserId,
    );

    await updateStore(storeId, {'activeInvite': invite.toMap()});
    return invite;
  }

  Future<StoreJoinResult> joinStoreWithInvite({
    required String userId,
    required String username,
    required String code,
  }) async {
    final sanitized = _sanitizeStoreUsername(username);
    final snapshot = await _firestore
        .collection('stores')
        .where('accessUsername', isEqualTo: sanitized)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('Usuário da loja não encontrado.');
    }

    final store = StoreModel.fromMap(snapshot.docs.first.data());
    final invite = store.activeInvite;
    if (invite == null || invite.code != code) {
      throw Exception('Código inválido.');
    }
    if (invite.isExpired) {
      await updateStore(store.id, {'activeInvite': null});
      throw Exception('O código expirou. Gere um novo acesso.');
    }
    if (store.memberUserIds.contains(userId)) {
      return StoreJoinResult(store: store, alreadyMember: true);
    }

    final user = await getUser(userId);
    if (user == null) {
      throw Exception('Usuário não encontrado.');
    }

    final updatedMembers = [
      ...store.members,
      StoreMember(
        userId: user.uid,
        name: user.fullName.isNotEmpty ? user.fullName : user.email,
        email: user.email,
        avatarUrl: user.profilePhoto,
        role: StoreMemberRole.member,
        joinedAt: DateTime.now(),
      ),
    ];
    final updatedUserIds = [...store.memberUserIds, user.uid];

    await updateStore(store.id, {
      'memberUserIds': updatedUserIds,
      'members': updatedMembers.map((member) => member.toMap()).toList(),
    });
    await addStoreToUser(user.uid, store.id);

    return StoreJoinResult(
      store: store.copyWith(
        memberUserIds: updatedUserIds,
        members: updatedMembers,
      ),
      alreadyMember: false,
    );
  }

  Future<void> updateStoreMemberRole({
    required String storeId,
    required String actingUserId,
    required String memberUserId,
    required StoreMemberRole role,
  }) async {
    final store = await getStore(storeId);
    if (store == null) throw Exception('Loja não encontrada.');
    if (!store.isAdmin(actingUserId)) {
      throw Exception('Apenas administradores podem alterar permissões.');
    }

    final updatedMembers = store.members
        .map(
          (member) => member.userId == memberUserId
              ? member.copyWith(role: role)
              : member,
        )
        .toList();
    final updatedAdmins = updatedMembers
        .where((member) => member.isAdmin)
        .map((member) => member.userId)
        .toList();

    await updateStore(storeId, {
      'members': updatedMembers.map((member) => member.toMap()).toList(),
      'adminUserIds': updatedAdmins,
    });
  }

  Future<void> removeStoreAdmin({
    required String storeId,
    required String actingUserId,
    required String memberUserId,
  }) async {
    final store = await getStore(storeId);
    if (store == null) throw Exception('Loja não encontrada.');
    if (actingUserId != store.ownerId) {
      throw Exception('Apenas o criador da loja pode remover admins.');
    }
    if (memberUserId == store.ownerId) {
      throw Exception('O criador da loja não pode deixar de ser admin.');
    }

    await updateStoreMemberRole(
      storeId: storeId,
      actingUserId: actingUserId,
      memberUserId: memberUserId,
      role: StoreMemberRole.member,
    );
  }

  Future<void> removeStoreMember({
    required String storeId,
    required String actingUserId,
    required String memberUserId,
  }) async {
    final store = await getStore(storeId);
    if (store == null) throw Exception('Loja não encontrada.');
    if (!store.isAdmin(actingUserId)) {
      throw Exception('Apenas administradores podem remover membros.');
    }
    if (memberUserId == store.ownerId) {
      throw Exception('O proprietário da loja não pode ser removido.');
    }

    final updatedMembers =
        store.members.where((member) => member.userId != memberUserId).toList();
    final updatedUserIds =
        store.memberUserIds.where((id) => id != memberUserId).toList();
    final updatedAdmins =
        store.adminUserIds.where((id) => id != memberUserId).toList();

    await updateStore(storeId, {
      'members': updatedMembers.map((member) => member.toMap()).toList(),
      'memberUserIds': updatedUserIds,
      'adminUserIds': updatedAdmins,
    });
    await removeStoreFromUser(memberUserId, storeId);
  }

  Future<List<StoreModel>> getStores({int limit = 15}) async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .limit(limit)
          .get();
      return snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('getStores falhou: $e');
      return [];
    }
  }

  Future<List<StoreModel>> getFeaturedStores({int limit = 15}) async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();
      final stores =
          snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
      stores.sort((a, b) => b.rating.compareTo(a.rating));
      return stores.take(limit).toList();
    } catch (e) {
      debugPrint('getFeaturedStores falhou: $e');
      return [];
    }
  }

  // ── Anúncios ──────────────────────────────────────────────────────────────

  String createAdDraftId() {
    return _firestore.collection('ads').doc().id;
  }

  Future<String> createAd(AdModel ad) async {
    final docRef = ad.id.trim().isNotEmpty
        ? _firestore.collection('ads').doc(ad.id)
        : _firestore.collection('ads').doc();
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
    String? intent,
    String? category,
    int limit = 20,
    DocumentSnapshot? startAfter,
    bool includeInactive = false,
  }) async {
    try {
      final fetchLimit = intent != null ? limit * 4 : limit;
      Query query =
          _firestore.collection('ads').orderBy('createdAt', descending: true);
      if (type != null) query = query.where('type', isEqualTo: type);
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }
      query = query.limit(fetchLimit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      var ads = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return AdModel.fromMap(data);
      }).toList();
      if (!includeInactive) {
        ads = ads.where((ad) => ad.isActive).toList();
      }
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      return ads.take(limit).toList();
    } catch (e) {
      debugPrint('getAds falhou, usando fallback sem filtros: $e');
      try {
        final fetchLimit = intent != null ? limit * 4 : limit;
        final snapshot = await _firestore
            .collection('ads')
            .orderBy('createdAt', descending: true)
            .limit(fetchLimit)
            .get();
        var ads = snapshot.docs.map((doc) {
          final data = doc.data();
          return AdModel.fromMap(data);
        }).toList();
        if (!includeInactive) {
          ads = ads.where((ad) => ad.isActive).toList();
        }
        if (type != null) {
          ads = ads.where((ad) => ad.type == type).toList();
        }
        if (intent != null) {
          ads = ads.where((ad) => ad.intent == intent).toList();
        }
        if (category != null) {
          ads = ads.where((ad) => ad.category == category).toList();
        }
        return ads.take(limit).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> getAdsByCategory(
    String category, {
    String? excludeAdId,
    String? intent,
    int limit = 6,
    bool includeInactive = false,
  }) async {
    try {
      final fetchLimit = (limit + (excludeAdId?.isNotEmpty == true ? 1 : 0)) *
          (intent != null ? 4 : 1);
      Query query = _firestore.collection('ads').where(
            'category',
            isEqualTo: category,
          );
      final snapshot = await query
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit)
          .get();
      var ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      if (!includeInactive) {
        ads = ads.where((ad) => ad.isActive).toList();
      }
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      return ads
          .where((ad) => excludeAdId == null || ad.id != excludeAdId)
          .take(limit)
          .toList();
    } catch (e) {
      debugPrint('getAdsByCategory($category) falhou, usando fallback: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .where('category', isEqualTo: category)
            .get();
        var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
        if (!includeInactive) {
          ads = ads.where((ad) => ad.isActive).toList();
        }
        if (intent != null) {
          ads = ads.where((ad) => ad.intent == intent).toList();
        }
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ads
            .where((ad) => excludeAdId == null || ad.id != excludeAdId)
            .take(limit)
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> getPersonalAdsByUser(
    String uid, {
    bool includeInactive = false,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('ads')
          .where('sellerId', isEqualTo: uid)
          .get();
      var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
      ads = ads.where((ad) => !ad.isStoreAd).toList();
      if (!includeInactive) {
        ads = ads.where((ad) => ad.isActive).toList();
      }
      ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ads;
    } catch (e) {
      debugPrint('getPersonalAdsByUser falhou, usando fallback: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .where('sellerId', isEqualTo: uid)
            .get();
        var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
        ads = ads.where((ad) => !ad.isStoreAd).toList();
        if (!includeInactive) {
          ads = ads.where((ad) => ad.isActive).toList();
        }
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ads;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> getAdsByStore(
    String storeId, {
    bool includeInactive = false,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('ads')
          .where('storeId', isEqualTo: storeId)
          .get();
      var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
      ads = ads.where((ad) => (ad.storeId ?? '').trim() == storeId).toList();
      if (!includeInactive) {
        ads = ads.where((ad) => ad.isActive).toList();
      }
      ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ads;
    } catch (e) {
      debugPrint('getAdsByStore falhou, usando fallback: $e');
      try {
        final snapshot = await _firestore
            .collection('ads')
            .where('storeId', isEqualTo: storeId)
            .get();
        var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
        ads = ads.where((ad) => (ad.storeId ?? '').trim() == storeId).toList();
        if (!includeInactive) {
          ads = ads.where((ad) => ad.isActive).toList();
        }
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return ads;
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<AdModel>> _getStoreAdsBySeller(String sellerId) async {
    try {
      final snapshot = await _firestore
          .collection('ads')
          .where('sellerId', isEqualTo: sellerId)
          .where('storeId', isNull: false)
          .get();
      final ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
      ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return ads;
    } catch (e) {
      debugPrint('_getStoreAdsBySeller falhou: $e');
      return [];
    }
  }

  Future<void> updateAd(String adId, Map<String, dynamic> data) async {
    await _firestore.collection('ads').doc(adId).update(data);
  }

  Future<void> deleteAd(String adId) async {
    final ad = await getAd(adId);
    if (ad != null) {
      if (ad.imagePublicIds.isNotEmpty) {
        await _cloudinary.deleteImages(ad.imagePublicIds);
      }
      for (final imageUrl in ad.images) {
        if (imageUrl.trim().isEmpty) continue;
        final deletedFromCloudinary =
            await _cloudinary.deleteImageByUrl(imageUrl);
        if (!deletedFromCloudinary &&
            !await _storage.deleteFileByUrl(imageUrl)) {
          await _queueCleanupFailure(
            entityType: 'ad',
            entityId: ad.id,
            assetUrl: imageUrl,
          );
        }
      }
    }
    await _firestore.collection('ads').doc(adId).delete();
  }

  Future<void> deleteStore({
    required String storeId,
    required String actingUserId,
  }) async {
    final store = await getStore(storeId);
    if (store == null) {
      throw Exception('Loja não encontrada.');
    }
    if (actingUserId != store.ownerId) {
      throw Exception('Apenas o criador da loja pode excluir a loja.');
    }

    final ads = await getAdsByStore(storeId);
    for (final ad in ads) {
      await deleteAd(ad.id);
    }

    final storeImageUrls = [
      if (store.logo != null && store.logo!.trim().isNotEmpty) store.logo!,
      if (store.banner != null && store.banner!.trim().isNotEmpty)
        store.banner!,
    ];
    for (final url in storeImageUrls) {
      final deletedFromCloudinary = await _cloudinary.deleteImageByUrl(url);
      if (!deletedFromCloudinary && !await _storage.deleteFileByUrl(url)) {
        await _queueCleanupFailure(
          entityType: 'store',
          entityId: store.id,
          assetUrl: url,
        );
      }
    }

    for (final memberId in store.memberUserIds) {
      await removeStoreFromUser(memberId, storeId);
    }

    await _firestore.collection('stores').doc(storeId).delete();
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  /// Cria ou retorna uma conversa existente entre dois usuários sobre um anúncio.
  /// Também salva o título do anúncio no documento do chat para exibição na lista.
  Future<List<Map<String, dynamic>>> getSaleBuyerCandidates(String adId) async {
    if (adId.isEmpty) return [];

    final snapshot = await _firestore
        .collection('chats')
        .where('adId', isEqualTo: adId)
        .get();

    final chatDocs = snapshot.docs
        .where((doc) => !doc.id.startsWith('direct_'))
        .toList(growable: false);
    final buyerIds = chatDocs
        .map((doc) => doc.data()['buyerId'] as String? ?? '')
        .where((buyerId) => buyerId.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    final users = await getUsersByIds(buyerIds);
    final usersById = {for (final user in users) user.uid: user};

    final candidates = chatDocs.map((doc) {
      final data = doc.data();
      final buyerId = data['buyerId'] as String? ?? '';
      final user = usersById[buyerId];
      final buyerName =
          user?.fullName.trim().isNotEmpty == true ? user!.fullName : 'Usuário';

      return <String, dynamic>{
        'chatId': doc.id,
        'buyerId': buyerId,
        'buyerName': buyerName,
        'buyerPhoto': user?.profilePhoto ?? '',
        'lastMessage': data['lastMessage'] ?? '',
        'lastMessageTime': data['lastMessageTime'],
      };
    }).toList();

    candidates.sort(
      (a, b) => _dateTimeFromDynamic(
        b['lastMessageTime'],
      ).compareTo(_dateTimeFromDynamic(a['lastMessageTime'])),
    );
    return candidates;
  }

  Future<void> markAdAsSold({
    required AdModel ad,
    required bool soldOnMarketView,
    String? buyerId,
    String? buyerName,
    String? buyerPhoto,
    String? chatId,
  }) async {
    final shouldAffectStoreRating = ad.storeId != null &&
        ad.storeId!.trim().isNotEmpty &&
        (ad.storeName?.trim().isNotEmpty ?? false) &&
        ad.sellerName.trim() == (ad.storeName?.trim() ?? '');
    final batch = _firestore.batch();
    final adRef = _firestore.collection('ads').doc(ad.id);
    batch.update(adRef, {
      'isActive': false,
      'soldAt': FieldValue.serverTimestamp(),
      'soldOnMarketView': soldOnMarketView,
      'soldToUserId': buyerId ?? '',
      'soldToUserName': buyerName ?? '',
      'soldChatId': chatId ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (soldOnMarketView && (buyerId?.trim().isNotEmpty ?? false)) {
      final resolvedBuyerId = buyerId!.trim();
      final requestId = 'sale_${ad.id}_$resolvedBuyerId';
      final requestRef =
          _firestore.collection('review_requests').doc(requestId);
      batch.set(requestRef, {
        'id': requestId,
        'status': 'pending',
        'adId': ad.id,
        'adTitle': ad.title,
        'adImage': ad.images.isNotEmpty ? ad.images.first : '',
        'sellerId': ad.sellerId,
        'sellerName': ad.displaySellerUserName.isNotEmpty
            ? ad.displaySellerUserName
            : ad.sellerName,
        'sellerAvatar': (ad.sellerUserAvatar ?? ad.sellerAvatar).trim(),
        'storeId': shouldAffectStoreRating ? (ad.storeId ?? '') : '',
        'storeName': shouldAffectStoreRating ? (ad.storeName ?? '') : '',
        'storeLogo': shouldAffectStoreRating ? (ad.storeLogo ?? '') : '',
        'affectsStoreRating': shouldAffectStoreRating,
        'buyerId': resolvedBuyerId,
        'buyerName': buyerName ?? '',
        'buyerPhoto': buyerPhoto ?? '',
        'chatId': chatId ?? '',
        'soldAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<String> getOrCreateChat(
    String buyerId,
    String sellerId,
    String adId, {
    String adTitle = '',
    String buyerName = '',
    String buyerPhoto = '',
    String sellerName = '',
    String sellerPhoto = '',
  }) async {
    // Validações básicas
    if (buyerId.isEmpty) {
      throw Exception('ID do comprador não pode estar vazio');
    }
    if (sellerId.isEmpty) {
      throw Exception(
        'Este anúncio não possui um responsável válido. '
        'Não é possível iniciar um chat.',
      );
    }
    if (buyerId == sellerId) {
      throw Exception('Você não pode iniciar um chat com você mesmo.');
    }

    try {
      final chatId = _buildAdChatId(
        buyerId: buyerId,
        sellerId: sellerId,
        adId: adId,
      );
      final docRef = _firestore.collection('chats').doc(chatId);
      await docRef.set({
        'id': docRef.id,
        'buyerId': buyerId,
        if (buyerName.trim().isNotEmpty) 'buyerName': buyerName.trim(),
        if (buyerPhoto.trim().isNotEmpty) 'buyerPhoto': buyerPhoto.trim(),
        'sellerId': sellerId,
        if (sellerName.trim().isNotEmpty) 'sellerName': sellerName.trim(),
        if (sellerPhoto.trim().isNotEmpty) 'sellerPhoto': sellerPhoto.trim(),
        'participants': [buyerId, sellerId],
        'adId': adId,
        if (adTitle.trim().isNotEmpty) 'adTitle': adTitle.trim(),
      }, SetOptions(merge: true));
      return docRef.id;
    } catch (e) {
      debugPrint('getOrCreateChat falhou: $e');
      rethrow;
    }
  }

  String _buildAdChatId({
    required String buyerId,
    required String sellerId,
    required String adId,
  }) {
    return 'ad_${adId.trim()}_${buyerId.trim()}_${sellerId.trim()}';
  }

  Future<String> getOrCreateDirectChat(
    String currentUserId,
    String otherUserId, {
    required String title,
    String currentUserName = '',
    String currentUserPhoto = '',
    String otherUserName = '',
    String otherUserPhoto = '',
  }) async {
    if (currentUserId.isEmpty || otherUserId.isEmpty) {
      throw Exception('N�o � poss�vel iniciar um chat.');
    }
    if (currentUserId == otherUserId) {
      throw Exception('Voc� n�o pode iniciar um chat com voc� mesmo.');
    }

    final participants = [currentUserId, otherUserId]..sort();
    final directKey = 'direct_${participants.join('_')}';
    final docRef = _firestore.collection('chats').doc(directKey);
    await docRef.set({
      'id': docRef.id,
      'buyerId': currentUserId,
      if (currentUserName.trim().isNotEmpty)
        'buyerName': currentUserName.trim(),
      if (currentUserPhoto.trim().isNotEmpty)
        'buyerPhoto': currentUserPhoto.trim(),
      'sellerId': otherUserId,
      if (otherUserName.trim().isNotEmpty) 'sellerName': otherUserName.trim(),
      if (otherUserPhoto.trim().isNotEmpty)
        'sellerPhoto': otherUserPhoto.trim(),
      'adId': directKey,
      if (title.trim().isNotEmpty) 'adTitle': title.trim(),
      'participants': participants,
    }, SetOptions(merge: true));
    return docRef.id;
  }

  Future<void> _sendChatPayload(
    String chatId,
    Map<String, dynamic> payload, {
    required String preview,
  }) async {
    final chatRef = _firestore.collection('chats').doc(chatId);
    final batch = _firestore.batch();

    final msgRef = chatRef.collection('messages').doc();
    batch.set(msgRef, {
      'id': msgRef.id,
      'time': FieldValue.serverTimestamp(),
      ...payload,
    });

    final chatPatch = <String, dynamic>{
      'id': chatRef.id,
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      if ((payload['senderName'] as String? ?? '').trim().isNotEmpty)
        'lastSenderName': (payload['senderName'] as String).trim(),
      if ((payload['senderPhoto'] as String? ?? '').trim().isNotEmpty)
        'lastSenderPhoto': (payload['senderPhoto'] as String).trim(),
      if ((payload['buyerFirstName'] as String? ?? '').trim().isNotEmpty)
        'lastSenderName': (payload['buyerFirstName'] as String).trim(),
      if ((payload['buyerPhoto'] as String? ?? '').trim().isNotEmpty)
        'lastSenderPhoto': (payload['buyerPhoto'] as String).trim(),
    };
    batch.set(chatRef, chatPatch, SetOptions(merge: true));

    await batch.commit();
  }

  /// Envia uma mensagem em uma conversa
  Future<void> sendMessage(
    String chatId,
    String senderId,
    String text, {
    String senderName = '',
    String senderPhoto = '',
  }) async {
    await _sendChatPayload(
      chatId,
      {
        'senderId': senderId,
        if (senderName.trim().isNotEmpty) 'senderName': senderName.trim(),
        if (senderPhoto.trim().isNotEmpty) 'senderPhoto': senderPhoto.trim(),
        'type': 'text',
        'text': text,
        'readBy': [senderId],
      },
      preview: text,
    );
  }

  Future<void> sendOfferMessage({
    required String chatId,
    required String senderId,
    required String buyerId,
    required String sellerId,
    required String buyerFirstName,
    String buyerPhoto = '',
    required String adId,
    required String adTitle,
    required double adPrice,
    required double offerPrice,
  }) async {
    await _sendChatPayload(
      chatId,
      {
        'senderId': senderId,
        'type': 'offer',
        'text': '',
        'offerStatus': 'pending',
        'buyerId': buyerId,
        'sellerId': sellerId,
        'buyerFirstName': buyerFirstName,
        if (buyerPhoto.trim().isNotEmpty) 'buyerPhoto': buyerPhoto.trim(),
        'adId': adId,
        'adTitle': adTitle,
        'adPrice': adPrice,
        'offerPrice': offerPrice,
        'counterPrice': null,
        'agreedPrice': null,
        'readBy': [senderId],
      },
      preview: 'Oferta enviada',
    );
  }

  Future<void> updateOfferMessage({
    required String chatId,
    required String messageId,
    required Map<String, dynamic> updates,
    required String preview,
  }) async {
    final batch = _firestore.batch();
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);
    batch.update(messageRef, updates);
    batch.update(_firestore.collection('chats').doc(chatId), {
      'lastMessage': preview,
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

  Future<void> markMessagesAsRead(
    String chatId,
    String readerId,
  ) async {
    if (chatId.trim().isEmpty || readerId.trim().isEmpty) return;

    final snapshot = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('senderId', isNotEqualTo: readerId)
        .get();

    final batch = _firestore.batch();
    var hasUpdates = false;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final readBy = (data['readBy'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false);
      if (readBy.contains(readerId)) continue;

      batch.set(
          doc.reference,
          {
            'readBy': FieldValue.arrayUnion([readerId]),
            'readAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));
      hasUpdates = true;
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }

  /// Stream de conversas de um usuário (ordenação local na tela)
  Stream<QuerySnapshot> getUserChatsStream(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots();
  }

  Future<void> _deleteChatsForUser(String uid) async {
    final snapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();
    for (final chatDoc in snapshot.docs) {
      await _deleteChat(chatDoc.reference);
    }
  }

  Future<void> _deleteChat(DocumentReference chatRef) async {
    final messages = await chatRef.collection('messages').get();
    for (final doc in messages.docs) {
      await doc.reference.delete();
    }
    await chatRef.delete();
  }

  Future<void> _deleteReviewsForUser(String uid) async {
    final revieweeSnapshot = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: uid)
        .get();
    for (final doc in revieweeSnapshot.docs) {
      await doc.reference.delete();
    }

    final reviewerSnapshot = await _firestore
        .collection('reviews')
        .where('reviewerId', isEqualTo: uid)
        .get();
    for (final doc in reviewerSnapshot.docs) {
      if (revieweeSnapshot.docs.any((existing) => existing.id == doc.id)) {
        continue;
      }
      await doc.reference.delete();
    }
  }

  Future<void> _removeFollowerReferences(String uid) async {
    final followers = await _firestore
        .collection('users')
        .where('followingSellerIds', arrayContains: uid)
        .get();
    for (final doc in followers.docs) {
      await doc.reference.update({
        'followingSellerIds': FieldValue.arrayRemove([uid]),
      });
    }
  }

  // ── Anúncios populares / recomendados ─────────────────────────────────────

  Future<void> _queueCleanupFailure({
    required String entityType,
    required String entityId,
    required String assetUrl,
  }) async {
    await _firestore.collection('maintenance_cleanup_queue').add({
      'entityType': entityType,
      'entityId': entityId,
      'assetUrl': assetUrl,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<AdModel>> getPopularAds({
    int limit = 6,
    DocumentSnapshot? startAfter,
    String? intent,
  }) async {
    try {
      final fetchLimit = startAfter != null
          ? (intent != null ? limit * 4 : limit)
          : limit * (intent != null ? 5 : 3);
      Query query = _firestore.collection('ads');
      query = query.orderBy('clickCount', descending: true).limit(fetchLimit);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      var ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      ads.sort((a, b) {
        final clickCmp = b.clickCount.compareTo(a.clickCount);
        if (clickCmp != 0) return clickCmp;
        return b.createdAt.compareTo(a.createdAt);
      });
      return ads.take(limit).toList();
    } catch (e) {
      debugPrint('getPopularAds falhou, usando fallback por createdAt: $e');
      final fetchLimit = intent != null ? limit * 4 : limit;
      final snapshot = await _firestore
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit)
          .get();
      var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      return ads.take(limit).toList();
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
    String? intent,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final resolvedCategory = AdModel.resolveCategoryValue(category);
    try {
      final fetchLimit = intent != null ? limit * 4 : limit;
      Query query = _firestore
          .collection('ads')
          .where('category', isEqualTo: resolvedCategory);
      query = query.orderBy('createdAt', descending: true).limit(fetchLimit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      var ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      return {'ads': ads.take(limit).toList(), 'lastDoc': lastDoc};
    } catch (e) {
      debugPrint(
          'getAdsByCategoryPaginated($resolvedCategory) falhou, usando fallback: $e');
      try {
        final fetchLimit = intent != null ? limit * 4 : limit;
        Query query = _firestore
            .collection('ads')
            .where('category', isEqualTo: resolvedCategory);
        query = query.limit(fetchLimit);
        if (startAfter != null) query = query.startAfterDocument(startAfter);
        final snapshot = await query.get();
        var ads = snapshot.docs
            .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        if (intent != null) {
          ads = ads.where((ad) => ad.intent == intent).toList();
        }
        ads.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        return {'ads': ads.take(limit).toList(), 'lastDoc': lastDoc};
      } catch (_) {
        return {'ads': <AdModel>[], 'lastDoc': null};
      }
    }
  }

  Future<Map<String, dynamic>> getRecommendedAdsPaginated(
    List<String> topCategories, {
    String? intent,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      final fetchLimit = intent != null ? limit * 4 : limit;
      if (topCategories.isEmpty) {
        Query query = _firestore.collection('ads');
        query = query.orderBy('clickCount', descending: true).limit(fetchLimit);
        if (startAfter != null) query = query.startAfterDocument(startAfter);
        final snapshot = await query.get();
        var ads = snapshot.docs
            .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
            .toList();
        if (intent != null) {
          ads = ads.where((ad) => ad.intent == intent).toList();
        }
        return {
          'ads': ads.take(limit).toList(),
          'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null
        };
      }
      final cats = topCategories.take(3).toList();
      Query query =
          _firestore.collection('ads').where('category', whereIn: cats);
      query = query.orderBy('createdAt', descending: true).limit(fetchLimit);
      if (startAfter != null) query = query.startAfterDocument(startAfter);
      final snapshot = await query.get();
      var ads = snapshot.docs
          .map((d) => AdModel.fromMap(d.data() as Map<String, dynamic>))
          .toList();
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      return {
        'ads': ads.take(limit).toList(),
        'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null
      };
    } catch (e) {
      debugPrint('getRecommendedAdsPaginated falhou, usando fallback: $e');
      final fetchLimit = intent != null ? limit * 4 : limit;
      final snapshot = await _firestore
          .collection('ads')
          .orderBy('createdAt', descending: true)
          .limit(fetchLimit)
          .get();
      var ads = snapshot.docs.map((d) => AdModel.fromMap(d.data())).toList();
      if (intent != null) {
        ads = ads.where((ad) => ad.intent == intent).toList();
      }
      return {
        'ads': ads.take(limit).toList(),
        'lastDoc': snapshot.docs.isNotEmpty ? snapshot.docs.last : null
      };
    }
  }

  Future<List<StoreModel>> getAllStores() async {
    try {
      final snapshot = await _firestore
          .collection('stores')
          .where('isActive', isEqualTo: true)
          .get();
      final stores =
          snapshot.docs.map((d) => StoreModel.fromMap(d.data())).toList();
      stores.sort((a, b) {
        final ratingComparison = b.rating.compareTo(a.rating);
        if (ratingComparison != 0) return ratingComparison;

        final reviewsComparison = b.totalReviews.compareTo(a.totalReviews);
        if (reviewsComparison != 0) return reviewsComparison;

        return b.createdAt.compareTo(a.createdAt);
      });
      return stores;
    } catch (e) {
      debugPrint('getAllStores falhou: $e');
      return [];
    }
  }

  Future<String> _generateUniqueStoreUsername(String storeName) async {
    final base = _sanitizeStoreUsername(storeName);
    var candidate = base;
    var suffix = 0;

    while (true) {
      final snapshot = await _firestore
          .collection('stores')
          .where('accessUsername', isEqualTo: candidate)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) {
        return candidate;
      }
      suffix++;
      candidate = '$base$suffix';
    }
  }

  String _sanitizeStoreUsername(String value) {
    final sanitized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return sanitized.isEmpty ? 'loja' : sanitized;
  }

  String _generateAccessCode() {
    final millis = DateTime.now().millisecondsSinceEpoch.toString();
    return millis.substring(millis.length - 8);
  }
}

class StoreJoinResult {
  final StoreModel store;
  final bool alreadyMember;

  const StoreJoinResult({
    required this.store,
    required this.alreadyMember,
  });
}
