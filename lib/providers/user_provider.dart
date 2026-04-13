import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _user;
  bool _loading = false;
  bool _hasResolvedCurrentUser = false;
  String? _activeLoadUid;
  int _marketplaceRefreshTick = 0;
  final List<String> _recentSearches = [];
  final FirestoreService _firestore = FirestoreService();
  bool _hasRequestedGuestLocation = false;

  UserModel? get user => _user;
  bool get loading => _loading;
  bool get hasResolvedCurrentUser => _hasResolvedCurrentUser;
  bool get isLoggedIn => FirebaseAuth.instance.currentUser != null;
  String? get uid => FirebaseAuth.instance.currentUser?.uid;
  int get marketplaceRefreshTick => _marketplaceRefreshTick;
  List<String> get recentSearches => List.unmodifiable(_recentSearches);
  bool get hasRequestedGuestLocation => _hasRequestedGuestLocation;

  void setGuestLocationRequested() {
    _hasRequestedGuestLocation = true;
    notifyListeners();
  }

  Future<void> loadUser(String uid, {bool force = false}) async {
    if (_loading && _activeLoadUid == uid) return;
    if (!force && _hasResolvedCurrentUser && _user?.uid == uid) return;

    _loading = true;
    _hasResolvedCurrentUser = false;
    _activeLoadUid = uid;
    notifyListeners();

    try {
      _user = await _firestore.getUser(uid);
    } finally {
      _loading = false;
      _hasResolvedCurrentUser = true;
      _activeLoadUid = null;
      notifyListeners();
    }
  }

  void setUser(UserModel user) {
    _user = user;
    notifyListeners();
  }

  void clear() {
    _user = null;
    _loading = false;
    _hasResolvedCurrentUser = true;
    _activeLoadUid = null;
    _recentSearches.clear();
    notifyListeners();
  }

  void saveSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    _recentSearches.removeWhere(
      (value) => value.toLowerCase() == trimmed.toLowerCase(),
    );
    _recentSearches.insert(0, trimmed);

    if (_recentSearches.length > 12) {
      _recentSearches.removeRange(12, _recentSearches.length);
    }

    notifyListeners();
  }

  Future<void> refresh() async {
    final uid = this.uid;
    if (uid == null) return;
    await loadUser(uid, force: true);
  }

  void notifyMarketplaceChanged() {
    _marketplaceRefreshTick++;
    notifyListeners();
  }

  bool isFollowingSeller(String sellerId) {
    if (_user == null || sellerId.isEmpty) return false;
    return _user!.followingSellerIds.contains(sellerId);
  }

  bool isFavoriteStore(String storeId) {
    if (_user == null || storeId.isEmpty) return false;
    return _user!.favoriteStoreIds.contains(storeId);
  }

  bool isPinnedChat(String chatId) {
    if (_user == null || chatId.isEmpty) return false;
    return _user!.pinnedChatIds.contains(chatId);
  }

  Future<void> toggleFollowSeller(String sellerId) async {
    if (_user == null || sellerId.isEmpty) return;

    final currentlyFollowing = _user!.followingSellerIds.contains(sellerId);
    final previous = List<String>.from(_user!.followingSellerIds);
    final updated = List<String>.from(_user!.followingSellerIds);
    if (currentlyFollowing) {
      updated.remove(sellerId);
    } else {
      updated.add(sellerId);
    }

    _user = _user!.copyWith(followingSellerIds: updated);
    notifyListeners();

    try {
      await _firestore.toggleFollowSeller(
        _user!.uid,
        sellerId,
        add: !currentlyFollowing,
      );
    } catch (e) {
      _user = _user!.copyWith(followingSellerIds: previous);
      notifyListeners();
      debugPrint('Erro ao atualizar seguindo: $e');
    }
  }

  Future<void> trackRecentlyViewedAd(String adId) async {
    if (_user == null || adId.isEmpty) return;

    final updated = List<String>.from(_user!.recentlyViewedAdIds)
      ..remove(adId)
      ..insert(0, adId);
    if (updated.length > 50) {
      updated.removeRange(50, updated.length);
    }

    _user = _user!.copyWith(recentlyViewedAdIds: updated);
    notifyListeners();

    try {
      await _firestore.trackRecentlyViewedAd(_user!.uid, adId);
    } catch (e) {
      debugPrint('Erro ao rastrear anúncio visto: $e');
    }
  }

  Future<void> toggleFavoriteStore(String storeId) async {
    if (_user == null || storeId.isEmpty) return;

    final currentlyFavorite = _user!.favoriteStoreIds.contains(storeId);
    final previous = List<String>.from(_user!.favoriteStoreIds);
    final updated = List<String>.from(_user!.favoriteStoreIds);
    if (currentlyFavorite) {
      updated.remove(storeId);
    } else {
      updated.add(storeId);
    }

    _user = _user!.copyWith(favoriteStoreIds: updated);
    notifyListeners();

    try {
      await _firestore.toggleFavoriteStore(
        _user!.uid,
        storeId,
        add: !currentlyFavorite,
      );
    } catch (e) {
      _user = _user!.copyWith(favoriteStoreIds: previous);
      notifyListeners();
      debugPrint('Erro ao atualizar favorito da loja: $e');
    }
  }

  Future<void> togglePinnedChat(String chatId) async {
    if (_user == null || chatId.isEmpty) return;

    final currentlyPinned = _user!.pinnedChatIds.contains(chatId);
    final previous = List<String>.from(_user!.pinnedChatIds);
    final updated = List<String>.from(_user!.pinnedChatIds);
    if (currentlyPinned) {
      updated.remove(chatId);
    } else {
      updated.insert(0, chatId);
    }

    _user = _user!.copyWith(pinnedChatIds: updated);
    notifyListeners();

    try {
      await _firestore.togglePinnedChat(
        _user!.uid,
        chatId,
        add: !currentlyPinned,
      );
    } catch (e) {
      _user = _user!.copyWith(pinnedChatIds: previous);
      notifyListeners();
      debugPrint('Erro ao atualizar conversa fixada: $e');
    }
  }

  Future<void> updateSearchArea({
    required AddressModel address,
    required int searchRadius,
  }) async {
    if (_user == null) return;

    final previousUser = _user!;
    _user = _user!.copyWith(address: address, searchRadius: searchRadius);
    notifyListeners();

    try {
      await _firestore.updateUserSearchArea(
        _user!.uid,
        address: address,
        searchRadius: searchRadius,
      );
      notifyMarketplaceChanged();
    } catch (e) {
      _user = previousUser;
      notifyListeners();
      debugPrint('Erro ao atualizar �rea de busca: $e');
    }
  }

  /// Registra um clique em uma categoria para o sistema de recomendação.
  /// Atualiza localmente e no Firestore de forma assíncrona.
  Future<void> trackCategoryClick(String category) async {
    if (_user == null) return;

    // Atualiza localmente primeiro para resposta imediata
    final updatedClicks = Map<String, int>.from(_user!.categoryClicks);
    updatedClicks[category] = (updatedClicks[category] ?? 0) + 1;
    _user = _user!.copyWith(categoryClicks: updatedClicks);
    notifyListeners();

    // Persiste no Firestore em background
    try {
      await _firestore.trackCategoryClick(_user!.uid, category);
    } catch (e) {
      debugPrint('Erro ao rastrear clique de categoria: $e');
    }
  }
}
