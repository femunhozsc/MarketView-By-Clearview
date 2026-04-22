import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import '../widgets/marketplace_controls.dart';
import 'ad_detail_screen.dart';
import 'category_ads_screen.dart';
import 'seller_profile_screen.dart';

const Map<String, List<String>> _stateAliasesByRegionKey = {
  'pr': ['pr', 'parana'],
  'sp': ['sp', 'sao paulo'],
  'rj': ['rj', 'rio de janeiro'],
  'mg': ['mg', 'minas gerais'],
  'sc': ['sc', 'santa catarina'],
  'rs': ['rs', 'rio grande do sul'],
  'ba': ['ba', 'bahia'],
  'go': ['go', 'goias'],
  'df': ['df', 'distrito federal', 'brasilia'],
  'br': ['brasil'],
};

const Color _marketCharcoal = Color(0xFF35393F);
const Color _marketMuted = Color(0xFF6B7280);
const Color _marketLine = Color(0xFFD1D5DB);
const List<String> _promoBannerAssets = [
  'assets/images/banner_ad_1.png',
  'assets/images/banner_ad_2.png',
  'assets/images/banner_ad_3.png',
  'assets/images/banner_ad_4.png',
  'assets/images/banner_ad_5.png',
];

List<String> _resolvePromoBannerSources(Map<String, dynamic>? data) {
  final resolved = <String>[];
  final bannerMap = data?['banners'];
  final normalizedBannerMap = bannerMap is Map
      ? Map<String, dynamic>.from(bannerMap)
      : const <String, dynamic>{};

  for (var index = 0; index < _promoBannerAssets.length; index++) {
    final slot = index + 1;
    final directUrl = (data?['banner${slot}Url'] ?? '').toString().trim();
    final nestedBanner = normalizedBannerMap['$slot'] is Map<String, dynamic>
        ? normalizedBannerMap['$slot'] as Map<String, dynamic>
        : normalizedBannerMap['$slot'] is Map
            ? Map<String, dynamic>.from(normalizedBannerMap['$slot'] as Map)
            : null;
    final nestedUrl = (nestedBanner?['imageUrl'] ?? '').toString().trim();
    final resolvedSource = directUrl.isNotEmpty
        ? directUrl
        : nestedUrl.isNotEmpty
            ? nestedUrl
            : _promoBannerAssets[index];
    resolved.add(resolvedSource);
  }

  return resolved;
}

String _normalizeLocationValue(String value) => AdModel.normalizeValue(value);

String _baseLocationLabel(String value) {
  return value.replaceFirst(RegExp(r'\s+[|\-]\s+\d+\s*km$'), '').trim();
}

double? _distanceKmForAd(
  AdModel ad,
  Distance distance,
  double searchLat,
  double searchLng,
) {
  if (searchLat == 0 || searchLng == 0 || ad.lat == null || ad.lng == null) {
    return null;
  }

  return distance.as(
    LengthUnit.Kilometer,
    LatLng(searchLat, searchLng),
    LatLng(ad.lat!, ad.lng!),
  );
}

bool _matchesStateLocation(AdModel ad, String regionKey) {
  final normalizedLocation = _normalizeLocationValue(ad.location);
  final aliases =
      _stateAliasesByRegionKey[_normalizeLocationValue(regionKey)] ??
          [_normalizeLocationValue(regionKey)];

  return aliases.any(
    (alias) =>
        normalizedLocation.contains(', $alias') ||
        normalizedLocation.endsWith(alias) ||
        normalizedLocation.contains(alias),
  );
}

bool _matchesSelectedLocationRule({
  required AdModel ad,
  required String locationScope,
  required String locationRegionKey,
  required String locationLabel,
  required double searchLat,
  required double searchLng,
  required int searchRadiusKm,
  required Distance distance,
}) {
  if (locationScope == 'country') {
    return true;
  }

  if (locationScope == 'state') {
    return _matchesStateLocation(ad, locationRegionKey);
  }

  final distanceKm = _distanceKmForAd(ad, distance, searchLat, searchLng);
  if (distanceKm != null) {
    return distanceKm <= searchRadiusKm;
  }

  final selectedRegion =
      _normalizeLocationValue(_baseLocationLabel(locationLabel));
  final adLocation = _normalizeLocationValue(ad.location);
  if (selectedRegion.isEmpty || adLocation.isEmpty) {
    return false;
  }

  return adLocation.contains(selectedRegion) ||
      selectedRegion.contains(adLocation);
}

int? _roundedDistanceKm(
  AdModel ad,
  Distance distance,
  String locationScope,
  double searchLat,
  double searchLng,
) {
  if (locationScope != 'city') return null;

  final distanceKm = _distanceKmForAd(ad, distance, searchLat, searchLng);
  if (distanceKm == null) return null;
  if (distanceKm > 0 && distanceKm < 1) return 1;
  return distanceKm.round();
}

// Tela "Ver Mais Recomendados" com scroll infinito
class AllRecommendedScreen extends StatefulWidget {
  final List<String> topCategories;
  final bool ignoreLocationFilter;
  final String locationScope;
  final String locationRegionKey;
  final double searchLat;
  final double searchLng;
  final int searchRadiusKm;
  final String locationLabel;

  const AllRecommendedScreen({
    super.key,
    required this.topCategories,
    this.ignoreLocationFilter = false,
    this.locationScope = 'city',
    this.locationRegionKey = '',
    this.searchLat = 0,
    this.searchLng = 0,
    this.searchRadiusKm = 50,
    this.locationLabel = '',
  });

  @override
  State<AllRecommendedScreen> createState() => _AllRecommendedScreenState();
}

class _AllRecommendedScreenState extends State<AllRecommendedScreen> {
  final _firestore = FirestoreService();
  final _scrollCtrl = ScrollController();
  final Distance _distance = const Distance();
  List<AdModel> _ads = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  int _lastMarketplaceRefreshTick = -1;

  @override
  void initState() {
    super.initState();
    _loadAds();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  List<AdModel> get _visibleAds {
    if (widget.ignoreLocationFilter) {
      return List<AdModel>.from(_ads);
    }

    final filtered = _ads.where((ad) {
      return _matchesSelectedLocationRule(
        ad: ad,
        locationScope: widget.locationScope,
        locationRegionKey: widget.locationRegionKey,
        locationLabel: widget.locationLabel,
        searchLat: widget.searchLat,
        searchLng: widget.searchLng,
        searchRadiusKm: widget.searchRadiusKm,
        distance: _distance,
      );
    }).toList();

    if (widget.locationScope == 'city') {
      filtered.sort((a, b) {
        final aDistance = _distanceKmForAd(
                a, _distance, widget.searchLat, widget.searchLng) ??
            double.infinity;
        final bDistance = _distanceKmForAd(
                b, _distance, widget.searchLat, widget.searchLng) ??
            double.infinity;
        return aDistance.compareTo(bDistance);
      });
    }

    return filtered;
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _loading = true);
    final result = await _firestore.getRecommendedAdsPaginated(
      widget.topCategories,
      limit: 20,
      intent: AdModel.intentSell,
    );
    if (mounted) {
      setState(() {
        _ads = result['ads'] as List<AdModel>;
        _lastDoc = result['lastDoc'] as DocumentSnapshot?;
        _hasMore = (_ads.length == 20);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final result = await _firestore.getRecommendedAdsPaginated(
      widget.topCategories,
      limit: 20,
      startAfter: _lastDoc,
      intent: AdModel.intentSell,
    );
    final newAds = result['ads'] as List<AdModel>;
    if (mounted) {
      setState(() {
        _ads.addAll(newAds);
        _lastDoc = result['lastDoc'] as DocumentSnapshot?;
        _hasMore = (newAds.length == 20);
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceRefreshTick =
        context.watch<UserProvider>().marketplaceRefreshTick;
    if (_lastMarketplaceRefreshTick != marketplaceRefreshTick) {
      _lastMarketplaceRefreshTick = marketplaceRefreshTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadAds();
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visibleAds = _visibleAds;
    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : _marketCharcoal,
              size: 22,
            ),
          ),
        ),
        title: Text(
          widget.topCategories.isEmpty
              ? 'Anuncios recomendados'
              : 'Recomendados para voce',
          style: GoogleFonts.roboto(
            color: isDark ? Colors.white : _marketCharcoal,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1,
              color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8)),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : visibleAds.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum anuncio encontrado nessa localizacao.',
                    style:
                        GoogleFonts.roboto(color: _marketMuted, fontSize: 14),
                  ),
                )
              : CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          mainAxisExtent: 236,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final ad = visibleAds[i];
                            return AdCard(
                              ad: ad,
                              index: i,
                              badgeLabel: widget.locationScope == 'state'
                                  ? (widget.ignoreLocationFilter
                                      ? null
                                      : 'Na regiao')
                                  : widget.locationScope == 'country'
                                      ? (widget.ignoreLocationFilter
                                          ? null
                                          : 'Brasil')
                                      : null,
                              distanceKm: _roundedDistanceKm(
                                ad,
                                _distance,
                                widget.ignoreLocationFilter
                                    ? 'country'
                                    : widget.locationScope,
                                widget.searchLat,
                                widget.searchLng,
                              ),
                              onTap: () {
                                context
                                    .read<UserProvider>()
                                    .trackCategoryClick(ad.category);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => AdDetailScreen(ad: ad)),
                                );
                              },
                            );
                          },
                          childCount: visibleAds.length,
                        ),
                      ),
                    ),
                    if (_loadingMore)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.facebookBlue)),
                        ),
                      ),
                    if (!_hasMore && visibleAds.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'Você viu todos os recomendados!',
                              style: GoogleFonts.roboto(
                                color: _marketMuted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
    );
  }
}

// -----------------------------------------------------------------------------

class ForYouScreen extends StatefulWidget {
  final VoidCallback? onViewMoreStores;
  final List<AdModel> initialAds;
  final List<StoreModel> initialStores;
  final List<AdModel> initialRecommendedAds;
  final Map<String, List<AdModel>> initialCategoryAds;
  final List<String> initialUserCategories;
  final int initialLoadedCategoryIndex;
  final Map<String, dynamic>? initialGlobalSettings;
  final Map<String, dynamic>? initialHomeBannerSettings;
  final MarketplaceFilters filters;
  final String locationScope;
  final String locationRegionKey;
  final double searchLat;
  final double searchLng;
  final int searchRadiusKm;
  final String locationLabel;

  const ForYouScreen({
    super.key,
    this.onViewMoreStores,
    this.initialAds = const [],
    this.initialStores = const [],
    this.initialRecommendedAds = const [],
    this.initialCategoryAds = const {},
    this.initialUserCategories = const [],
    this.initialLoadedCategoryIndex = 0,
    this.initialGlobalSettings,
    this.initialHomeBannerSettings,
    this.filters = MarketplaceFilters.empty,
    this.locationScope = 'city',
    this.locationRegionKey = '',
    this.searchLat = 0,
    this.searchLng = 0,
    this.searchRadiusKm = 50,
    this.locationLabel = '',
  });

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  final FirestoreService _firestore = FirestoreService();
  final ScrollController _scrollController = ScrollController();
  final Distance _distance = const Distance();

  // Dados
  List<AdModel> _recommendedAds = [];
  List<StoreModel> _featuredStores = [];
  final Map<String, List<AdModel>> _categoryAds = {};
  List<String> _userCategories = [];
  int _loadedCategoryIndex = 0;

  bool _loadingRecommended = true;
  bool _loadingStores = true;
  bool _loadingMoreCategories = false;
  bool _isNewUser = true;
  int _lastMarketplaceRefreshTick = -1;

  // Ordem padrão de categorias para novos usuários
  static const List<String> _defaultCategoryOrder = categories;

  bool get _isGuestDiscoveryMode {
    final user = context.read<UserProvider>().user;
    return user == null && _isNewUser;
  }

  List<String> _mergeCategoryOrder(List<String> priorityCategories) {
    final ordered = <String>[];

    for (final category in priorityCategories) {
      if (category.isEmpty || ordered.contains(category)) continue;
      ordered.add(category);
    }

    for (final category in _defaultCategoryOrder) {
      if (!ordered.contains(category)) {
        ordered.add(category);
      }
    }

    return ordered;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final seeded = _seedInitialData();
    if (!seeded) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadNextCategory();
    }
  }

  bool _seedInitialData() {
    _resolveUserCategories();

    if (widget.initialUserCategories.isNotEmpty) {
      _userCategories = List<String>.from(widget.initialUserCategories);
    }

    if (widget.initialRecommendedAds.isNotEmpty) {
      _recommendedAds = List<AdModel>.from(widget.initialRecommendedAds);
      _loadingRecommended = false;
    } else if (widget.initialAds.isNotEmpty) {
      _recommendedAds = _buildSeedRecommendedAds(widget.initialAds);
      _loadingRecommended = false;
    }

    if (widget.initialCategoryAds.isNotEmpty) {
      _categoryAds.addAll(
        widget.initialCategoryAds.map(
          (key, value) => MapEntry(key, List<AdModel>.from(value)),
        ),
      );
      _loadedCategoryIndex = widget.initialLoadedCategoryIndex;
    } else if (widget.initialAds.isNotEmpty && _userCategories.isNotEmpty) {
      final firstCategoryAds =
          _buildSeedCategoryAds(_userCategories.first, widget.initialAds);
      if (firstCategoryAds.isNotEmpty) {
        _categoryAds[_userCategories.first] = firstCategoryAds;
        _loadedCategoryIndex = 1;
      }
    }

    if (widget.initialStores.isNotEmpty) {
      _featuredStores = List<StoreModel>.from(widget.initialStores);
      _loadingStores = false;
    }

    return !_loadingRecommended && !_loadingStores;
  }

  void _resolveUserCategories() {
    final userProvider = context.read<UserProvider>();

    if (userProvider.hasPersonalizedTasteProfile) {
      _isNewUser = false;
      _userCategories =
          _mergeCategoryOrder(userProvider.topCategoryPreferences);
      return;
    }

    _isNewUser = true;
    _userCategories = List.from(_defaultCategoryOrder);
  }

  List<AdModel> _sortSeedAds(Iterable<AdModel> ads) {
    final sorted = ads.toList()
      ..sort((a, b) {
        final clicksComparison = b.clickCount.compareTo(a.clickCount);
        if (clicksComparison != 0) return clicksComparison;
        return b.createdAt.compareTo(a.createdAt);
      });
    return sorted;
  }

  List<AdModel> _buildSeedRecommendedAds(List<AdModel> ads) {
    final saleAds = _sortSeedAds(
      ads.where((ad) => ad.intent == AdModel.intentSell),
    );

    if (_isNewUser) {
      return saleAds.take(12).toList();
    }

    final seenIds = <String>{};
    final recommended = <AdModel>[];

    for (final category in _userCategories.take(3)) {
      for (final ad in saleAds.where((item) => item.category == category)) {
        if (seenIds.add(ad.id)) {
          recommended.add(ad);
        }
      }
    }

    for (final ad in saleAds) {
      if (seenIds.add(ad.id)) {
        recommended.add(ad);
      }
    }

    return recommended.take(12).toList();
  }

  List<AdModel> _buildSeedCategoryAds(String category, List<AdModel> ads) {
    return _sortSeedAds(
      ads.where(
        (ad) => ad.intent == AdModel.intentSell && ad.category == category,
      ),
    ).take(12).toList();
  }

  Future<void> _loadInitialData() async {
    final userProvider = context.read<UserProvider>();

    if (mounted) {
      setState(() {
        _loadingRecommended = true;
        _loadingStores = true;
        _loadingMoreCategories = false;
        _recommendedAds = [];
        _featuredStores = [];
        _categoryAds.clear();
        _loadedCategoryIndex = 0;
      });
    }

    // Determina se é novo usuário e define categorias
    if (userProvider.hasPersonalizedTasteProfile) {
      _isNewUser = false;
      // Usuário com interesses: coloca as categorias favoritas primeiro
      _userCategories =
          _mergeCategoryOrder(userProvider.topCategoryPreferences);
    } else {
      _isNewUser = true;
      final trendingCategories = await _firestore.getTrendingCategories(
        limit: _defaultCategoryOrder.length,
        intent: AdModel.intentSell,
      );
      _userCategories = _mergeCategoryOrder(trendingCategories);
    }

    // Carrega em paralelo: recomendados + lojas + primeira categoria
    await Future.wait([
      _loadRecommendedAds(),
      _loadFeaturedStores(),
    ]);

    // Carrega primeira categoria
    if (_userCategories.isNotEmpty) {
      await _loadCategoryAds(_userCategories[0]);
      if (mounted) setState(() => _loadedCategoryIndex = 1);
    }
  }

  Future<void> _loadRecommendedAds() async {
    try {
      List<AdModel> recommended = [];

      if (_isNewUser) {
        final popular = await _firestore.getPopularAds(
          limit: 30,
          intent: AdModel.intentSell,
        );
        final recent = await _firestore.getAds(
          limit: 30,
          intent: AdModel.intentSell,
        );
        final existingIds = popular.map((ad) => ad.id).toSet();
        recommended = [...popular];
        recommended.addAll(recent.where((a) => !existingIds.contains(a.id)));
      } else {
        // Usuário com interesses: busca pelas top 3 categorias
        final topCats = _userCategories.take(3).toList();
        for (final cat in topCats) {
          final ads = await _firestore.getAdsByCategory(
            cat,
            limit: 4,
            intent: AdModel.intentSell,
          );
          recommended.addAll(ads);
        }
        // Completa com populares se necessário
        if (recommended.length < 6) {
          final popular = await _firestore.getPopularAds(
            limit: 12,
            intent: AdModel.intentSell,
          );
          final existingIds = recommended.map((a) => a.id).toSet();
          recommended.addAll(popular.where((a) => !existingIds.contains(a.id)));
        }
      }

      if (mounted) {
        setState(() {
          _recommendedAds = recommended.take(12).toList();
          _loadingRecommended = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRecommended = false);
    }
  }

  Future<void> _loadFeaturedStores() async {
    try {
      // Busca TODAS as lojas ativas (sem limite)
      final stores = await _firestore.getAllStores();
      if (mounted) {
        setState(() {
          _featuredStores = stores;
          _loadingStores = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  Future<void> _loadCategoryAds(String category) async {
    if (_categoryAds.containsKey(category)) return;
    try {
      final ads = await _firestore.getAdsByCategory(
        category,
        limit: 12,
        intent: AdModel.intentSell,
      );
      if (mounted) {
        setState(() {
          _categoryAds[category] = ads;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar categoria $category: $e');
    }
  }

  Future<void> _loadNextCategory() async {
    if (_loadingMoreCategories) return;
    if (_loadedCategoryIndex >= _userCategories.length) return;

    setState(() => _loadingMoreCategories = true);

    final category = _userCategories[_loadedCategoryIndex];
    await _loadCategoryAds(category);

    if (mounted) {
      setState(() {
        _loadedCategoryIndex++;
        _loadingMoreCategories = false;
      });
    }
  }

  bool _matchesSelectedLocation(AdModel ad) {
    if (_isGuestDiscoveryMode) {
      return true;
    }

    return _matchesSelectedLocationRule(
      ad: ad,
      locationScope: widget.locationScope,
      locationRegionKey: widget.locationRegionKey,
      locationLabel: widget.locationLabel,
      searchLat: widget.searchLat,
      searchLng: widget.searchLng,
      searchRadiusKm: widget.searchRadiusKm,
      distance: _distance,
    );
  }

  int? _roundedDistanceKmForAd(AdModel ad) {
    return _roundedDistanceKm(
      ad,
      _distance,
      widget.locationScope,
      widget.searchLat,
      widget.searchLng,
    );
  }

  String? _badgeLabelForAd() {
    if (_isGuestDiscoveryMode) return null;
    if (widget.locationScope == 'state') return 'Na regiao';
    if (widget.locationScope == 'country') return 'Brasil';
    return null;
  }

  SliverGridDelegate _gridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900
        ? 4
        : width >= 680
            ? 3
            : 2;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      mainAxisExtent: 236,
    );
  }

  void _navigateToAd(AdModel ad) {
    // Rastreia o clique na categoria
    context.read<UserProvider>().trackCategoryClick(ad.category);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => AdDetailScreen(ad: ad),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _navigateToCategory(String category) {
    context.read<UserProvider>().trackCategoryClick(category);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryAdsScreen(
          category: category,
          icon: _getCategoryIcon(category),
          ignoreLocationFilter: _isGuestDiscoveryMode,
          locationScope: widget.locationScope,
          locationRegionKey: widget.locationRegionKey,
          searchLat: widget.searchLat,
          searchLng: widget.searchLng,
          searchRadiusKm: widget.searchRadiusKm,
          locationLabel: widget.locationLabel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceRefreshTick =
        context.watch<UserProvider>().marketplaceRefreshTick;
    if (_lastMarketplaceRefreshTick != marketplaceRefreshTick) {
      _lastMarketplaceRefreshTick = marketplaceRefreshTick;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadInitialData();
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<UserProvider>().user;
    final userName = user?.firstName ?? 'Usuário';
    final recommendedAds = _applyFilters(_recommendedAds).take(6).toList();
    final hour = DateTime.now().hour;
    const marketBlue = Color(0xFF0066EE);
    final greeting = hour >= 5 && hour < 12
        ? 'Bom dia'
        : hour >= 12 && hour < 19
            ? 'Boa tarde'
            : 'Boa noite';
    final defaultHeaderSubtitle = (user == null || _isNewUser)
        ? 'Os anuncios de destaque mais populares na comunidade'
        : 'Separamos esses ultimos anuncios de acordo com seu gosto';

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // -- Header principal -----------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 16, 0),
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('app_config')
                    .doc('global_settings')
                    .snapshots(),
                builder: (context, snapshot) {
                  final settings =
                      snapshot.data?.data() ?? widget.initialGlobalSettings;
                  final showPromotionalBanner =
                      settings?['showPromotionalBanner'] != false;
                  final welcomeMessage =
                      (settings?['welcomeMessage'] ?? '').toString().trim();
                  final headerSubtitle = welcomeMessage.isNotEmpty
                      ? welcomeMessage
                      : defaultHeaderSubtitle;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '$greeting, ',
                              style: GoogleFonts.montserrat(
                                fontSize: 27,
                                height: 1.06,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: isDark ? Colors.white : _marketCharcoal,
                              ),
                            ),
                            TextSpan(
                              text: userName,
                              style: GoogleFonts.montserrat(
                                fontSize: 27,
                                height: 1.06,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.8,
                                color: marketBlue,
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideX(begin: -0.08, end: 0),
                      if (showPromotionalBanner) ...[
                        const SizedBox(height: 14),
                        _HomePromoBanner(
                          isDark: isDark,
                          initialBannerSettings:
                              widget.initialHomeBannerSettings,
                        )
                            .animate(delay: 70.ms)
                            .fadeIn(duration: 420.ms)
                            .slideY(begin: 0.08, end: 0),
                      ],
                      const SizedBox(height: 14),
                      Text(
                        headerSubtitle,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.5,
                          height: 1.35,
                          color:
                              isDark ? AppTheme.whiteSecondary : _marketMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
                    ],
                  );
                },
              ),
            ),
          ),

          // -- Recomendados (6 cards em grid) ----------------------
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          _loadingRecommended
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                          color: AppTheme.facebookBlue),
                    ),
                  ),
                )
              : recommendedAds.isEmpty
                  ? SliverToBoxAdapter(
                      child: _emptyState(
                        'Nenhum anúncio disponível nessa localização',
                        'Tente ampliar o raio ou trocar a região selecionada.',
                        Icons.auto_awesome_rounded,
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => AdCard(
                            ad: recommendedAds[index],
                            index: index,
                            badgeLabel: _badgeLabelForAd(),
                            distanceKm:
                                _roundedDistanceKmForAd(recommendedAds[index]),
                            onTap: () => _navigateToAd(recommendedAds[index]),
                          ),
                          childCount: recommendedAds.length,
                        ),
                        gridDelegate: _gridDelegate(context),
                      ),
                    ),

          // -- Botão "Ver mais recomendados" -----------------------
          if (!_loadingRecommended && recommendedAds.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AllRecommendedScreen(
                          topCategories: _isNewUser
                              ? []
                              : _userCategories.take(3).toList(),
                          ignoreLocationFilter: _isGuestDiscoveryMode,
                          locationScope: widget.locationScope,
                          locationRegionKey: widget.locationRegionKey,
                          searchLat: widget.searchLat,
                          searchLng: widget.searchLng,
                          searchRadiusKm: widget.searchRadiusKm,
                          locationLabel: widget.locationLabel,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: isDark ? AppTheme.blackBorder : _marketLine,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Ver mais recomendados',
                    style: GoogleFonts.roboto(
                      color: isDark ? AppTheme.whiteSecondary : _marketMuted,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn(),
              ),
            ),

          // -- Seção "Lojas Destaque" ------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 24, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lojas Destaque',
                    style: GoogleFonts.roboto(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : _marketCharcoal,
                    ),
                  ),
                  GestureDetector(
                    onTap: widget.onViewMoreStores,
                    child: Text(
                      'Ver mais',
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.whiteSecondary : _marketMuted,
                      ),
                    ),
                  ),
                ],
              ).animate(delay: 300.ms).fadeIn(),
            ),
          ),

          SliverToBoxAdapter(
            child: _buildStoresCarousel(isDark),
          ),

          // -- Categorias por interesse (lazy loaded) --------------
          ..._buildCategorySections(isDark),

          // -- Loading indicator para mais categorias --------------
          if (_loadingMoreCategories)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppTheme.facebookBlue)),
              ),
            ),

          // Espaçamento final
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // -- Carrossel de Lojas --------------------------------------------------
  Widget _buildStoresCarousel(bool isDark) {
    if (_loadingStores) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
            child: CircularProgressIndicator(color: AppTheme.facebookBlue)),
      );
    }

    if (_featuredStores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          'Nenhuma loja cadastrada no momento',
          style: GoogleFonts.roboto(color: _marketMuted, fontSize: 14),
        ),
      );
    }

    return SizedBox(
      height: 154,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        // Mostra todas as lojas + botão "ver mais" no final
        itemCount: _featuredStores.length + 1,
        itemBuilder: (context, index) {
          if (index == _featuredStores.length) {
            // Botão "Ver mais" no final do carrossel
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: widget.onViewMoreStores,
                child: Container(
                  width: 96,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppTheme.blackBorder
                          : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.facebookBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: AppTheme.facebookBlue, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ver mais',
                        style: GoogleFonts.roboto(
                          color:
                              isDark ? AppTheme.whiteSecondary : _marketMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final store = _featuredStores[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerProfileScreen(
                      sellerId: store.ownerId,
                      sellerName: store.name,
                      storeId: store.id,
                    ),
                  ),
                );
              },
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.blackCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.04,
                      ),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Foto de perfil da loja
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.facebookBlue.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: store.logo != null
                            ? Image.network(
                                store.logo!,
                                fit: BoxFit.cover,
                                width: 60,
                                height: 60,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.facebookBlue
                                      .withValues(alpha: 0.1),
                                  child: const Icon(Icons.store_rounded,
                                      color: AppTheme.facebookBlue, size: 26),
                                ),
                              )
                            : Container(
                                color: AppTheme.facebookBlue
                                    .withValues(alpha: 0.1),
                                child: const Icon(Icons.store_rounded,
                                    color: AppTheme.facebookBlue, size: 26),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Nome da loja
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        store.name,
                        style: GoogleFonts.montserrat(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : _marketCharcoal,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Estrelas de avaliação
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFC107), size: 13),
                        const SizedBox(width: 2),
                        Text(
                          store.rating > 0
                              ? store.rating.toStringAsFixed(1)
                              : 'Novo',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppTheme.whiteMuted : _marketMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
                .animate(delay: Duration(milliseconds: index * 40))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.15, end: 0),
          );
        },
      ),
    );
  }

  // -- Seções de Categorias ------------------------------------------------
  List<Widget> _buildCategorySections(bool isDark) {
    final widgets = <Widget>[];

    for (int i = 0;
        i < _loadedCategoryIndex && i < _userCategories.length;
        i++) {
      final category = _userCategories[i];
      final ads =
          _applyFilters(_categoryAds[category] ?? const []).take(6).toList();

      if (ads.isEmpty) continue;

      // Título da categoria
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 26, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        color: AppTheme.facebookBlue,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AdModel.displayLabel(category),
                      style: GoogleFonts.roboto(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : _marketCharcoal,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _navigateToCategory(category),
                  child: Text(
                    'Ver mais',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppTheme.whiteSecondary : _marketMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Grid de anúncios da categoria
      widgets.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => AdCard(
                ad: ads[index],
                index: index,
                badgeLabel: _badgeLabelForAd(),
                distanceKm: _roundedDistanceKmForAd(ads[index]),
                onTap: () => _navigateToAd(ads[index]),
              ),
              childCount: ads.length,
            ),
            gridDelegate: _gridDelegate(context),
          ),
        ),
      );

      // Botão "Ver mais" da categoria
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton(
              onPressed: () => _navigateToCategory(category),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                side: BorderSide(
                  color: isDark ? AppTheme.blackBorder : _marketLine,
                ),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Ver mais em ${AdModel.displayLabel(category)}',
                style: GoogleFonts.roboto(
                  color: isDark ? AppTheme.whiteSecondary : _marketMuted,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  Widget _emptyState(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _marketMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style:
                GoogleFonts.roboto(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Eletronicos':
      case 'Eletrônicos':
        return Icons.devices_rounded;
      case 'Veiculos':
      case 'Veículos':
        return Icons.directions_car_rounded;
      case 'Imoveis':
      case 'Imóveis':
        return Icons.home_rounded;
      case 'Moveis':
      case 'Móveis':
        return Icons.chair_rounded;
      case 'Roupas':
        return Icons.checkroom_rounded;
      case 'Esportes':
        return Icons.sports_soccer_rounded;
      case 'Assistencia tecnica':
        return Icons.build_circle_rounded;
      case 'Aulas e cursos':
      case 'Educação':
        return Icons.school_rounded;
      case 'Consultoria':
        return Icons.support_agent_rounded;
      case 'Design':
        return Icons.design_services_rounded;
      case 'Design e marketing':
        return Icons.campaign_rounded;
      case 'Eventos':
        return Icons.celebration_rounded;
      case 'Fretes e mudancas':
        return Icons.local_shipping_rounded;
      case 'Limpeza':
        return Icons.cleaning_services_rounded;
      case 'Reformas e manutencao':
        return Icons.handyman_rounded;
      case 'Saude e bem-estar':
      case 'Saúde':
        return Icons.health_and_safety_rounded;
      case 'Beleza e estetica':
      case 'Beleza':
        return Icons.content_cut_rounded;
      case 'Servicos pet':
      case 'Animais':
        return Icons.pets_rounded;
      case 'Vaga de emprego':
        return Icons.work_outline_rounded;
      case 'Outros servicos':
        return Icons.miscellaneous_services_rounded;
      default:
        return Icons.sell_rounded;
    }
  }

  List<AdModel> _applyFilters(List<AdModel> source) {
    final filtered = source.where((ad) {
      if (!_matchesSelectedLocation(ad)) return false;
      return widget.filters.matchesAd(ad);
    }).toList();

    if (widget.locationScope == 'city') {
      filtered.sort((a, b) {
        final aDistance = _distanceKmForAd(
                a, _distance, widget.searchLat, widget.searchLng) ??
            double.infinity;
        final bDistance = _distanceKmForAd(
                b, _distance, widget.searchLat, widget.searchLng) ??
            double.infinity;
        return aDistance.compareTo(bDistance);
      });
    }

    switch (widget.filters.sort) {
      case MarketplaceSort.newest:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MarketplaceSort.priceLow:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case MarketplaceSort.priceHigh:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case MarketplaceSort.recommended:
        break;
    }

    return filtered;
  }
}

class _HomePromoBanner extends StatefulWidget {
  const _HomePromoBanner({
    required this.isDark,
    this.initialBannerSettings,
  });

  final bool isDark;
  final Map<String, dynamic>? initialBannerSettings;

  @override
  State<_HomePromoBanner> createState() => _HomePromoBannerState();
}

class _HomePromoBannerState extends State<_HomePromoBanner> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        widget.isDark ? AppTheme.blackBorder : const Color(0xFFE1E7EF);
    final shadowColor = widget.isDark
        ? Colors.black.withValues(alpha: 0.2)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_config')
          .doc('home_banners')
          .snapshots(),
      builder: (context, snapshot) {
        final bannerSources = _resolvePromoBannerSources(
          snapshot.data?.data() ?? widget.initialBannerSettings,
        );

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 16 / 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: bannerSources.length,
                    onPageChanged: (index) {
                      if (!mounted) return;
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final source = bannerSources[index];
                      final placeholder = Container(
                        color: widget.isDark
                            ? const Color(0xFF131922)
                            : const Color(0xFFF3F6FA),
                        alignment: Alignment.center,
                        child: Text(
                          'Banner ${index + 1}',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: widget.isDark
                                ? Colors.white70
                                : const Color(0xFF334155),
                          ),
                        ),
                      );

                      if (source.startsWith('http')) {
                        return Image.network(
                          source,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => placeholder,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return placeholder;
                          },
                        );
                      }

                      return Image.asset(
                        source,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => placeholder,
                      );
                    },
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(bannerSources.length, (index) {
                        final selected = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          width: selected ? 18 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.46),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
