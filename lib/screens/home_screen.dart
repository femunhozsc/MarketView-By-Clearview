import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/ad_card.dart';
import '../widgets/marketplace_controls.dart';
import '../widgets/pill_sections.dart';
import '../widgets/top_bar.dart';
import 'create_ad_screen.dart';
import 'ad_detail_screen.dart';
import 'chat_screen.dart';
import 'favorites_screen.dart';
import 'follow_network_screen.dart';
import 'location_picker_screen.dart';
import 'profile_screen.dart';
import 'reviews_screen.dart';
import 'recently_viewed_screen.dart';
import 'sales_activity_screen.dart';
import 'for_you_screen.dart';
import 'category_ads_screen.dart';
import 'my_ads_screen.dart';
import 'my_stores_screen.dart';
import 'search_results_screen.dart';
import 'settings_screen.dart';
import 'stores_screen.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../providers/user_provider.dart';
import '../models/user_model.dart';
import 'seller_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.initialAds,
    this.initialStores,
    this.initialForYouRecommendedAds = const [],
    this.initialForYouCategoryAds = const {},
    this.initialForYouCategories = const [],
    this.initialForYouLoadedCategoryIndex = 0,
  });

  final List<AdModel>? initialAds;
  final List<StoreModel>? initialStores;
  final List<AdModel> initialForYouRecommendedAds;
  final Map<String, List<AdModel>> initialForYouCategoryAds;
  final List<String> initialForYouCategories;
  final int initialForYouLoadedCategoryIndex;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  static const double _campoMouraoLat = -24.0466;
  static const double _campoMouraoLng = -52.3780;
  static const int _sectionCount = 7;
  static const double _pillSectionsHeight = 69;
  static const double _marketplaceActionsHeight = 60;
  static const List<String> _sellerStrengthOptions = [
    'Atencioso',
    'Comunicacao rapida',
    'Pontual',
    'Honesto',
    'Produto conforme o anuncio',
  ];
  final Distance _distance = const Distance();
  // PÃ­lulas: 0=Para VocÃª, 1=Produtos, 2=ServiÃ§os, 3=Lojas, 4=Categorias, 5=Favoritos
  int _selectedSection = 0;
  int _selectedNavIndex = 0;
  bool _isDrawerOpen = false;
  bool _isSearching = false;
  bool _locationInitialized = false;
  String _searchQuery = '';
  List<UserModel> _userSearchSuggestions = [];
  List<StoreModel> _storeSearchSuggestions = [];
  bool _isLoadingUserSearch = false;
  String _locationLabel = 'Campo MourÃ£o, PR Â· 50km';
  String _locationScope = 'city';
  String _locationRegionKey = 'campo mourao';
  final _searchController = TextEditingController();
  MarketplaceFilters _filters = MarketplaceFilters.empty;
  double _searchLat = _campoMouraoLat;
  double _searchLng = _campoMouraoLng;
  int _searchRadiusKm = 50;
  final ValueNotifier<double> _marketplaceChromeOffset = ValueNotifier(0);

  late AnimationController _drawerCtrl;
  late Animation<double> _drawerAnim;
  late final PageController _sectionsPageController;

  @override
  void initState() {
    super.initState();
    _realAds = List<AdModel>.from(widget.initialAds ?? const []);
    _realStores = List<StoreModel>.from(widget.initialStores ?? const []);
    if (_realAds.isEmpty || _realStores.isEmpty) {
      _loadAds();
    }
    _sectionsPageController = PageController(initialPage: _selectedSection);
    _drawerCtrl = AnimationController(
      duration: const Duration(milliseconds: 320),
      vsync: this,
    );
    _drawerAnim =
        CurvedAnimation(parent: _drawerCtrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _drawerCtrl.dispose();
    _sectionsPageController.dispose();
    _searchController.dispose();
    _marketplaceChromeOffset.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_locationInitialized) {
      _maybePromptPendingReview();
      return;
    }

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;

    if (user == null && !userProvider.hasRequestedGuestLocation) {
      userProvider.setGuestLocationRequested();
      _initGuestLocation();
      return;
    }

    final lat = user?.address.lat ?? _campoMouraoLat;
    final lng = user?.address.lng ?? _campoMouraoLng;
    final radius = user?.searchRadius ?? 50;
    final baseLabel = (user != null &&
            user.address.city.isNotEmpty &&
            user.address.state.isNotEmpty)
        ? '${user.address.city}, ${user.address.state}'
        : 'Campo Mourao, PR';

    _searchLat = lat;
    _searchLng = lng;
    _searchRadiusKm = radius;
    _locationLabel = user == null ? 'Brasil' : '$baseLabel - ${radius}km';
    _locationScope = user == null ? 'country' : 'city';
    _locationRegionKey =
        _normalizeRegionValue(user?.address.city ?? 'campo mourao');
    _locationInitialized = true;
    _maybePromptPendingReview();
  }

  Future<void> _initGuestLocation() async {
    // Defaults to country search before fetching location
    _searchLat = _campoMouraoLat;
    _searchLng = _campoMouraoLng;
    _searchRadiusKm = 300;
    _locationLabel = 'Brasil';
    _locationScope = 'country';
    _locationRegionKey = 'br';
    _locationInitialized = true;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final position = await Geolocator.getCurrentPosition();
        final point = LatLng(position.latitude, position.longitude);

        if (mounted) {
          setState(() {
            _searchLat = point.latitude;
            _searchLng = point.longitude;
          });
        }
      }
    } catch (_) {}
  }

  void _toggleDrawer() {
    setState(() => _isDrawerOpen = !_isDrawerOpen);
    _isDrawerOpen ? _drawerCtrl.forward() : _drawerCtrl.reverse();
  }

  void _handleAuthRequired(VoidCallback action) {
    if (context.read<UserProvider>().user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
    } else {
      action();
    }
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
      _selectedNavIndex = 0;
    });
  }

  void _closeSearch() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _userSearchSuggestions = [];
      _storeSearchSuggestions = [];
      _isLoadingUserSearch = false;
      _searchController.clear();
      _marketplaceChromeOffset.value = 0;
    });
  }

  void _commitSearchSuggestion(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    FocusScope.of(context).unfocus();
    context.read<UserProvider>().saveSearchQuery(trimmed);
    setState(() {
      _searchQuery = trimmed;
      _searchController.text = trimmed;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
      _userSearchSuggestions = [];
      _storeSearchSuggestions = [];
      _isSearching = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          initialQuery: trimmed,
          ads: _realAds,
          stores: _realStores,
          filters: _filters,
          locationScope: _locationScope,
          locationRegionKey: _locationRegionKey,
          searchLat: _searchLat,
          searchLng: _searchLng,
          searchRadiusKm: _searchRadiusKm,
          locationLabel: _locationLabel,
        ),
      ),
    );
  }

  Future<void> _onSearchChanged(String value) async {
    final trimmed = value.trim();
    setState(() {
      _searchQuery = value;
      if (trimmed.isEmpty) {
        _userSearchSuggestions = [];
        _storeSearchSuggestions = [];
        _isLoadingUserSearch = false;
      } else {
        _isLoadingUserSearch = true;
      }
    });

    if (trimmed.isEmpty) return;

    final results = await Future.wait([
      _firestore.searchUsersByName(trimmed, limit: 3),
      _firestore.searchStoresByName(trimmed, limit: 4),
    ]);
    if (!mounted || _searchController.text.trim() != trimmed) return;

    setState(() {
      _userSearchSuggestions = results[0] as List<UserModel>;
      _storeSearchSuggestions = _mergeStoreSuggestions(
        trimmed,
        remoteResults: results[1] as List<StoreModel>,
        limit: 4,
      );
      _isLoadingUserSearch = false;
    });
  }

  List<StoreModel> _mergeStoreSuggestions(
    String query, {
    required List<StoreModel> remoteResults,
    int limit = 4,
  }) {
    final byId = <String, StoreModel>{};
    for (final store in remoteResults) {
      if (store.id.trim().isNotEmpty) {
        byId[store.id] = store;
      }
    }
    for (final store in _localStoreSuggestions(query, limit: limit)) {
      if (store.id.trim().isNotEmpty) {
        byId.putIfAbsent(store.id, () => store);
      }
    }

    final ranked = byId.values.toList()
      ..sort((a, b) {
        final scoreCompare =
            _storeSuggestionScore(b, query).compareTo(_storeSuggestionScore(a, query));
        if (scoreCompare != 0) return scoreCompare;
        return b.rating.compareTo(a.rating);
      });
    return ranked.take(limit).toList();
  }

  List<StoreModel> _localStoreSuggestions(String query, {int limit = 4}) {
    final normalizedQuery = AdModel.normalizeValue(query);
    if (normalizedQuery.isEmpty) return const [];

    final ranked = _realStores
        .where((store) => store.isActive)
        .map((store) => MapEntry(store, _storeSuggestionScore(store, query)))
        .where((entry) => entry.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ranked.take(limit).map((entry) => entry.key).toList();
  }

  int _storeSuggestionScore(StoreModel store, String query) {
    final normalizedQuery = AdModel.normalizeValue(query).trim();
    if (normalizedQuery.isEmpty) return 0;

    final terms = normalizedQuery
        .split(RegExp(r'[^a-z0-9]+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final name = AdModel.normalizeValue(store.name);
    final category = AdModel.normalizeValue(store.category);
    final description = AdModel.normalizeValue(store.description);
    final city = AdModel.normalizeValue(store.address.city);
    final state = AdModel.normalizeValue(store.address.state);

    var score = 0;
    if (name == normalizedQuery) score += 220;
    if (name.startsWith(normalizedQuery)) score += 160;
    if (name.contains(normalizedQuery)) score += 110;
    if (category.contains(normalizedQuery)) score += 40;
    if (description.contains(normalizedQuery)) score += 22;
    if (city.contains(normalizedQuery) || state.contains(normalizedQuery)) {
      score += 14;
    }

    for (final term in terms) {
      if (name.contains(term)) score += 18;
      if (category.contains(term)) score += 12;
      if (description.contains(term)) score += 6;
    }

    return score;
  }

  void _setSelectedSection(
    int index, {
    bool animate = true,
    bool fromPageView = false,
  }) {
    final nextIndex = index.clamp(0, _sectionCount - 1).toInt();
    _marketplaceChromeOffset.value = 0;
    if (_selectedSection != nextIndex) {
      setState(() => _selectedSection = nextIndex);
    }

    if (!fromPageView && _sectionsPageController.hasClients) {
      if (animate) {
        _sectionsPageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } else {
        _sectionsPageController.jumpToPage(nextIndex);
      }
    }
  }

  double _marketplaceChromeMaxHeight(bool showMarketplaceActions) {
    return showMarketplaceActions
        ? _pillSectionsHeight + _marketplaceActionsHeight
        : _pillSectionsHeight;
  }

  bool _handleHomeScrollNotification(ScrollNotification notification) {
    if (_isSearching) return false;
    if (notification.metrics.axis != Axis.vertical) return false;

    final showMarketplaceActions = _selectedSection == 1 ||
        _selectedSection == 2 ||
        _selectedSection == 4 ||
        _selectedSection == 6;
    final maxOffset = _marketplaceChromeMaxHeight(showMarketplaceActions);

    if (notification.metrics.pixels <= 0) {
      if (_marketplaceChromeOffset.value != 0) {
        _marketplaceChromeOffset.value = 0;
      }
      return false;
    }

    if (notification is ScrollUpdateNotification &&
        notification.scrollDelta != null) {
      final nextOffset =
          (_marketplaceChromeOffset.value + notification.scrollDelta!)
              .clamp(0.0, maxOffset);
      if ((nextOffset - _marketplaceChromeOffset.value).abs() > 1) {
        _marketplaceChromeOffset.value = nextOffset;
      }
    } else if (notification is ScrollEndNotification &&
        _marketplaceChromeOffset.value > 0 &&
        _marketplaceChromeOffset.value < maxOffset) {
      final targetOffset =
          _marketplaceChromeOffset.value > (maxOffset / 2) ? maxOffset : 0.0;
      if ((targetOffset - _marketplaceChromeOffset.value).abs() > 1) {
        _marketplaceChromeOffset.value = targetOffset;
      }
    }

    return false;
  }

  Future<bool> _handleBackNavigation() async {
    if (_isSearching) {
      _closeSearch();
      return false;
    }
    if (_selectedNavIndex != 0) {
      setState(() => _selectedNavIndex = 0);
      return false;
    }
    if (_selectedSection != 0) {
      _setSelectedSection(0);
      return false;
    }
    return true;
  }

  final _firestore = FirestoreService();
  List<AdModel> _realAds = [];
  List<StoreModel> _realStores = [];
  bool _isLoadingAds = false;
  int _lastMarketplaceRefreshTick = -1;
  bool _isCheckingPendingReviews = false;
  String? _pendingReviewCheckUid;

  Future<void> _loadAds() async {
    if (!mounted) return;
    setState(() => _isLoadingAds = true);
    try {
      final ads = await _firestore.getAds(limit: 60);
      final stores = await _firestore.getStores(limit: 60);
      if (!mounted) return;
      setState(() {
        _realAds = ads;
        _realStores = stores;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingAds = false);
      }
    }
  }

  Future<void> _refreshMarketplace() async {
    await _loadAds();
    if (!mounted) return;
    context.read<UserProvider>().notifyMarketplaceChanged();
  }

  void _maybePromptPendingReview() {
    final uid = context.read<UserProvider>().user?.uid;
    if (uid == null || uid.isEmpty || _isCheckingPendingReviews) return;
    if (_pendingReviewCheckUid == uid) return;

    _pendingReviewCheckUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _promptPendingReviews(uid);
    });
  }

  Future<void> _promptPendingReviews(String uid) async {
    if (_isCheckingPendingReviews) return;
    _isCheckingPendingReviews = true;

    try {
      while (mounted) {
        final pendingRequests = await _firestore.getPendingReviewRequests(uid);
        if (pendingRequests.isEmpty) break;

        final submission =
            await _showPendingReviewDialog(pendingRequests.first);
        if (!mounted || submission == null) break;

        final reviewer = context.read<UserProvider>().user;
        if (reviewer == null) break;

        await _firestore.submitSaleReview(
          reviewRequestId: pendingRequests.first['id'] as String,
          reviewerId: reviewer.uid,
          reviewerName: reviewer.fullName.trim().isNotEmpty
              ? reviewer.fullName
              : 'Usuário',
          reviewerAvatar: reviewer.profilePhoto,
          rating: submission['rating'] as int,
          strengths: List<String>.from(
            submission['strengths'] as List<dynamic>? ?? const [],
          ),
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avaliação enviada com sucesso.')),
        );
      }
    } finally {
      _isCheckingPendingReviews = false;
    }
  }

  Future<Map<String, dynamic>?> _showPendingReviewDialog(
    Map<String, dynamic> request,
  ) async {
    var selectedRating = 0;
    final selectedStrengths = <String>{};

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        final subtitleColor =
            isDark ? AppTheme.whiteSecondary : Colors.grey.shade700;
        final sellerName =
            (request['sellerName'] as String? ?? 'Vendedor').trim().isNotEmpty
                ? (request['sellerName'] as String).trim()
                : 'Vendedor';
        final storeName = (request['storeName'] as String? ?? '').trim();
        final sellerAvatar = (request['sellerAvatar'] as String? ?? '').trim();
        final adTitle = (request['adTitle'] as String? ?? '').trim();

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'Avalie sua compra',
              style: GoogleFonts.roboto(
                color: textColor,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppTheme.facebookBlue.withValues(alpha: 0.12),
                        backgroundImage: sellerAvatar.isNotEmpty
                            ? NetworkImage(sellerAvatar)
                            : null,
                        child: sellerAvatar.isEmpty
                            ? Text(
                                sellerName[0].toUpperCase(),
                                style: GoogleFonts.roboto(
                                  color: AppTheme.facebookBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sellerName,
                              style: GoogleFonts.roboto(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (storeName.isNotEmpty)
                              Text(
                                storeName,
                                style: GoogleFonts.roboto(
                                  color: AppTheme.facebookBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (adTitle.isNotEmpty)
                              Text(
                                adTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.roboto(
                                  color: subtitleColor,
                                  fontSize: 12.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Como foi sua experiência?',
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(
                      5,
                      (index) => IconButton(
                        onPressed: () {
                          setDialogState(() => selectedRating = index + 1);
                        },
                        icon: Icon(
                          index < selectedRating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: Colors.amber,
                          size: 32,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 40,
                          height: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pontos fortes do vendedor',
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _sellerStrengthOptions.map((strength) {
                      final isSelected = selectedStrengths.contains(strength);
                      return FilterChip(
                        label: Text(strength),
                        selected: isSelected,
                        onSelected: (selected) {
                          setDialogState(() {
                            if (selected) {
                              selectedStrengths.add(strength);
                            } else {
                              selectedStrengths.remove(strength);
                            }
                          });
                        },
                        selectedColor:
                            AppTheme.facebookBlue.withValues(alpha: 0.14),
                        checkmarkColor: AppTheme.facebookBlue,
                        labelStyle: GoogleFonts.roboto(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppTheme.facebookBlue.withValues(alpha: 0.30)
                              : (isDark
                                  ? AppTheme.blackBorder
                                  : const Color(0xFFE5E7EB)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Depois'),
              ),
              FilledButton(
                onPressed: selectedRating == 0
                    ? null
                    : () => Navigator.of(dialogContext).pop({
                          'rating': selectedRating,
                          'strengths': selectedStrengths.toList(),
                        }),
                child: const Text('Enviar avaliação'),
              ),
            ],
          ),
        );
      },
    );
  }

  double? _distanceKmForAd(AdModel ad) {
    if (ad.lat == null || ad.lng == null) return null;
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(_searchLat, _searchLng),
      LatLng(ad.lat!, ad.lng!),
    );
  }

  String _normalizeRegionValue(String value) {
    return AdModel.normalizeValue(value);
  }

  bool _matchesStateLocation(AdModel ad, String regionKey) {
    final normalizedLocation = _normalizeRegionValue(ad.location);
    final aliasesByState = <String, List<String>>{
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
    final aliases = aliasesByState[regionKey] ?? [regionKey];
    return aliases.any(
      (alias) =>
          normalizedLocation.contains(', $alias') ||
          normalizedLocation.endsWith(alias) ||
          normalizedLocation.contains(alias),
    );
  }

  bool _matchesSelectedLocation(AdModel ad) {
    if (_locationScope == 'country') {
      return true;
    }
    if (_locationScope == 'state') {
      return _matchesStateLocation(ad, _locationRegionKey);
    }

    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm != null) {
      return distanceKm <= _searchRadiusKm;
    }

    final selectedRegion =
        _normalizeRegionValue(_locationLabel.split(' - ').first);
    final adLocation = _normalizeRegionValue(ad.location);
    if (selectedRegion.isEmpty || adLocation.isEmpty) {
      return false;
    }
    return adLocation.contains(selectedRegion) ||
        selectedRegion.contains(adLocation);
  }

  bool _isSameRegionAsSelected(AdModel ad) {
    final selectedRegion =
        _normalizeRegionValue(_locationLabel.split(' - ').first);
    final adLocation = _normalizeRegionValue(ad.location);
    if (selectedRegion.isEmpty || adLocation.isEmpty) return false;
    return adLocation.contains(selectedRegion) ||
        selectedRegion.contains(adLocation);
  }

  bool _isOutsideRadius(AdModel ad) {
    if (_locationScope != 'city') return false;
    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm == null) return false;
    if (_isSameRegionAsSelected(ad)) return false;
    return distanceKm > _searchRadiusKm;
  }

  int? _roundedDistanceKmForAd(AdModel ad) {
    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm == null) return null;
    if (distanceKm > 0 && distanceKm < 1) return 1;
    return distanceKm.round();
  }

  String _badgeLabelForAd(AdModel ad) {
    if (_locationScope == 'state') return 'Na regiao';
    if (_locationScope == 'country') return 'Brasil';
    return _isOutsideRadius(ad) ? 'Fora do raio' : 'Nas proximidades';
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _searchLat,
          initialLng: _searchLng,
          initialRadiusKm: _searchRadiusKm,
          initialLabel: _locationLabel.split(' - ').first,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _searchLat = result.lat;
      _searchLng = result.lng;
      _searchRadiusKm = result.radiusKm;
      _locationScope = result.scope;
      _locationRegionKey = _normalizeRegionValue(result.regionKey);
      _locationLabel = result.scope == 'city'
          ? '${result.label} - ${result.radiusKm}km'
          : result.label;
    });

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user != null && result.scope == 'city') {
      await userProvider.updateSearchArea(
        address: user.address.copyWith(
          lat: result.lat,
          lng: result.lng,
        ),
        searchRadius: result.radiusKm,
      );
    } else {
      userProvider.notifyMarketplaceChanged();
    }
  }

  List<AdModel> _filteredAdsForSection(int sectionIndex) {
    List<AdModel> ads = _realAds.isEmpty ? sampleAds : _realAds;
    switch (sectionIndex) {
      case 1:
        ads = ads
            .where((a) =>
                a.intent == AdModel.intentSell && a.type == AdModel.productType)
            .toList();
        break;
      case 2:
        ads = ads
            .where((a) =>
                a.intent == AdModel.intentSell && a.type == AdModel.serviceType)
            .toList();
        break;
      case 4:
        ads = ads.where((a) => a.intent == AdModel.intentBuy).toList();
        break;
      case 6:
        final user = context.read<UserProvider>().user;
        if (user != null) {
          ads = ads.where((a) => user.favoriteAdIds.contains(a.id)).toList();
        } else {
          ads = [];
        }
        break;
    }
    if (_searchQuery.isNotEmpty) {
      ads = ads
          .where((a) =>
              a.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              a.category.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    ads = ads.where(_matchesSelectedLocation).where(_matchesFilters).toList();
    ads = _sortAds(ads);
    if (_locationScope == 'city') {
      ads.sort((a, b) {
        final aDistance = _distanceKmForAd(a) ?? double.infinity;
        final bDistance = _distanceKmForAd(b) ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
    }
    return ads;
  }

  List<String> _searchTextSuggestions(List<String> recentSearches) {
    final rawQuery = _searchQuery.trim();
    final query = AdModel.normalizeValue(rawQuery);
    if (query.isEmpty) return const [];

    final suggestions = <String>[rawQuery];
    final seen = <String>{query};

    void addSuggestion(String value) {
      final trimmed = value.trim();
      final normalized = AdModel.normalizeValue(trimmed);
      if (trimmed.isEmpty || normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      suggestions.add(trimmed);
      seen.add(normalized);
    }

    final oneWordCandidates = <String>[];
    final titleCandidates = <String>[];

    for (final previous in recentSearches) {
      final normalized = AdModel.normalizeValue(previous);
      if (!normalized.contains(query)) continue;
      if (previous.trim().contains(' ')) {
        titleCandidates.add(previous);
      } else {
        oneWordCandidates.add(previous);
      }
    }

    final sourceAds = _realAds.isEmpty ? sampleAds : _realAds;
    for (final ad in sourceAds) {
      final title = ad.title.trim();
      final normalizedTitle = AdModel.normalizeValue(title);
      if (!normalizedTitle.contains(query)) continue;

      titleCandidates.add(title);

      for (final word in title.split(RegExp(r'\s+'))) {
        final cleaned = word.trim();
        final normalizedWord = AdModel.normalizeValue(cleaned);
        if (normalizedWord.startsWith(query)) {
          oneWordCandidates.add(cleaned);
        }
      }
    }

    oneWordCandidates.sort((a, b) {
      final aNorm = AdModel.normalizeValue(a);
      final bNorm = AdModel.normalizeValue(b);
      final aStarts = aNorm.startsWith(query);
      final bStarts = bNorm.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.length.compareTo(b.length);
    });

    titleCandidates.sort((a, b) {
      final aNorm = AdModel.normalizeValue(a);
      final bNorm = AdModel.normalizeValue(b);
      final aStarts = aNorm.startsWith(query);
      final bStarts = bNorm.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.length.compareTo(b.length);
    });

    for (final candidate in oneWordCandidates) {
      addSuggestion(candidate);
      if (suggestions.length >= 2) break;
    }

    for (final candidate in titleCandidates) {
      addSuggestion(candidate);
      if (suggestions.length >= 8) break;
    }

    return suggestions;
  }

  Widget _buildSearchSuggestions(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final query = _searchQuery.trim();
    final recentSearches = context.watch<UserProvider>().recentSearches;
    final textSuggestions = _searchTextSuggestions(recentSearches);

    if (query.isEmpty) {
      return Center(
        child: Text(
          'Digite para buscar anuncios, lojas e perfis',
          style: GoogleFonts.roboto(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        if (_isLoadingUserSearch)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppTheme.facebookBlue,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Pesquisar por',
            style: GoogleFonts.roboto(
              color: Colors.grey,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...textSuggestions.map(
          (suggestion) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              suggestion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.north_west_rounded,
              color: Colors.grey,
              size: 18,
            ),
            onTap: () => _commitSearchSuggestion(suggestion),
          ),
        ),
        if (_storeSearchSuggestions.isNotEmpty) const SizedBox(height: 10),
        if (_storeSearchSuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Lojas',
              style: GoogleFonts.roboto(
                color: Colors.grey,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ..._storeSearchSuggestions.map(
            (store) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                tileColor: cardColor,
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.facebookBlue.withValues(alpha: 0.12),
                  backgroundImage: store.logo != null &&
                          store.logo!.trim().isNotEmpty
                      ? NetworkImage(store.logo!)
                      : null,
                  child: store.logo == null || store.logo!.trim().isEmpty
                      ? const Icon(
                          Icons.storefront_rounded,
                          color: AppTheme.facebookBlue,
                        )
                      : null,
                ),
                title: Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  store.address.city.isNotEmpty
                      ? '${AdModel.displayLabel(store.category)} · ${store.address.city}, ${store.address.state}'
                      : AdModel.displayLabel(store.category),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontSize: 12.5,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: Color(0xFFF4B400),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      store.totalReviews > 0
                          ? store.rating.toStringAsFixed(1)
                          : '--',
                      style: GoogleFonts.roboto(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isSearching = false;
                    _userSearchSuggestions = [];
                    _storeSearchSuggestions = [];
                  });
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
              ),
            ),
          ),
        ],
        if (_userSearchSuggestions.isNotEmpty) const SizedBox(height: 10),
        if (_userSearchSuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Usuarios',
              style: GoogleFonts.roboto(
                color: Colors.grey,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ..._userSearchSuggestions.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                tileColor: cardColor,
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.facebookBlue.withValues(alpha: 0.12),
                  backgroundImage: user.profilePhoto != null &&
                          user.profilePhoto!.trim().isNotEmpty
                      ? NetworkImage(user.profilePhoto!)
                      : null,
                  child: user.profilePhoto == null ||
                          user.profilePhoto!.trim().isEmpty
                      ? Text(
                          user.firstName.isNotEmpty
                              ? user.firstName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.roboto(
                            color: AppTheme.facebookBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  user.fullName,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  user.address.city.isNotEmpty
                      ? '${user.address.city}, ${user.address.state}'
                      : 'Perfil de usuario',
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontSize: 12.5,
                  ),
                ),
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() {
                    _isSearching = false;
                    _userSearchSuggestions = [];
                    _storeSearchSuggestions = [];
                  });
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SellerProfileScreen(
                        sellerId: user.uid,
                        sellerName: user.fullName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _matchesFilters(AdModel ad) {
    return _filters.matchesAd(ad);
  }

  List<AdModel> _sortAds(List<AdModel> ads) {
    final sorted = List<AdModel>.from(ads);
    switch (_filters.sort) {
      case MarketplaceSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MarketplaceSort.priceLow:
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case MarketplaceSort.priceHigh:
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case MarketplaceSort.recommended:
        sorted.sort((a, b) {
          final clickDiff = b.clickCount.compareTo(a.clickCount);
          if (clickDiff != 0) return clickDiff;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }
    return sorted;
  }

  SliverGridDelegate _marketplaceGridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 980
        ? 4
        : width >= 720
            ? 3
            : 2;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      mainAxisExtent: 236,
    );
  }

  // â”€â”€ Navega para tela de acordo com Ã­ndice da barra inferior
  Widget _getScreen() {
    switch (_selectedNavIndex) {
      case 3:
        return const ChatScreen();
      case 4:
        return const ProfileScreen(showAppBar: false);
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locationLabel = _locationLabel;
    final showMarketplaceActions = _selectedSection == 1 ||
        _selectedSection == 2 ||
        _selectedSection == 4 ||
        _selectedSection == 6;
    final chromeHeight = _marketplaceChromeMaxHeight(showMarketplaceActions);
    return Column(
      children: [
        if (!_isSearching)
          RepaintBoundary(
            child: ValueListenableBuilder<double>(
              valueListenable: _marketplaceChromeOffset,
              builder: (context, chromeOffsetValue, _) {
                final chromeOffset = chromeOffsetValue.clamp(0.0, chromeHeight);
                final visibleChromeHeight =
                    (chromeHeight - chromeOffset).clamp(0.0, chromeHeight);

                return ClipRect(
                  child: SizedBox(
                    height: visibleChromeHeight,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: chromeHeight,
                      maxHeight: chromeHeight,
                      child: Transform.translate(
                        offset: Offset(0, -chromeOffset),
                        child: SizedBox(
                          height: chromeHeight,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.black : Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      color: isDark
                                          ? AppTheme.blackBorder
                                          : const Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: PillSections(
                                  selectedIndex: _selectedSection,
                                  onSectionChanged: _setSelectedSection,
                                ),
                              ),
                              if (showMarketplaceActions)
                                MarketplaceLocationActions(
                                  locationLabel: locationLabel,
                                  onLocationTap: _openLocationPicker,
                                  onFiltersTap: _openFilters,
                                  onSavedTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const FavoritesScreen(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleHomeScrollNotification,
            child: RepaintBoundary(
              child: PageView.builder(
                controller: _sectionsPageController,
                itemCount: _sectionCount,
                onPageChanged: (index) => _setSelectedSection(
                  index,
                  animate: false,
                  fromPageView: true,
                ),
                itemBuilder: (context, index) =>
                    _buildSectionContent(isDark, index),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(bool isDark, int sectionIndex) {
    switch (sectionIndex) {
      case 0: // Para VocÃª
        return ForYouScreen(
          initialAds: _realAds,
          initialStores: _realStores,
          initialRecommendedAds: widget.initialForYouRecommendedAds,
          initialCategoryAds: widget.initialForYouCategoryAds,
          initialUserCategories: widget.initialForYouCategories,
          initialLoadedCategoryIndex: widget.initialForYouLoadedCategoryIndex,
          filters: _filters,
          locationScope: _locationScope,
          locationRegionKey: _locationRegionKey,
          searchLat: _searchLat,
          searchLng: _searchLng,
          searchRadiusKm: _searchRadiusKm,
          locationLabel: _locationLabel,
          onViewMoreStores: () {
            _setSelectedSection(3);
          },
        );
      case 3: // Lojas
        return StoresScreen(
          stores: _realStores,
          isLoading: _isLoadingAds,
          onRefresh: _refreshMarketplace,
          locationScope: _locationScope,
          locationRegionKey: _locationRegionKey,
          searchLat: _searchLat,
          searchLng: _searchLng,
          searchRadiusKm: _searchRadiusKm,
          locationLabel: _locationLabel,
        );
      case 5: // Categorias
        return _buildCategoriesGrid(isDark);
      default: // Produtos, Servi\u00E7os, Compro, Favoritos
        return _buildFeed(isDark, sectionIndex);
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
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;

    return PopScope(
      canPop: !_isSearching && _selectedNavIndex == 0 && _selectedSection == 0,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: (_selectedNavIndex == 3)
            ? null
            : (_isSearching
                ? _buildSearchBar(isDark)
                : MarketViewTopBar(
                    onMenuTap: _toggleDrawer,
                    onSearchTap: () {
                      if (_selectedNavIndex != 0) {
                        setState(() => _selectedNavIndex = 0);
                      }
                      _setSelectedSection(0, animate: false);
                      _openSearch();
                    },
                    onLogoTap: () {
                      FocusScope.of(context).unfocus();
                      setState(() {
                        _selectedNavIndex = 0;
                      });
                      _setSelectedSection(0, animate: false);
                      _loadAds();
                    },
                  )),
        body: Stack(
          children: [
            _isSearching ? _buildSearchSuggestions(isDark) : _getScreen(),
            if (_isDrawerOpen)
              GestureDetector(
                onTap: _toggleDrawer,
                child: AnimatedBuilder(
                  animation: _drawerAnim,
                  builder: (_, __) => Container(
                    color: Colors.black.withValues(
                      alpha: 0.55 * _drawerAnim.value,
                    ),
                  ),
                ),
              ),
            AnimatedBuilder(
              animation: _drawerAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(312 * (1 - _drawerAnim.value), 0),
                child: child,
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: _buildDrawer(isDark),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(isDark),
      ),
    );
  }

  // â”€â”€ SearchBar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  PreferredSizeWidget _buildSearchBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppTheme.black : Colors.white,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: GoogleFonts.roboto(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Buscar an\u00FAncios, pedidos, lojas e servi\u00E7os',
                  hintStyle:
                      GoogleFonts.roboto(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: Colors.grey, size: 22),
                  filled: true,
                  fillColor:
                      isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _closeSearch,
              style: TextButton.styleFrom(
                minimumSize: const Size(88, 48),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                'Cancelar',
                style: GoogleFonts.roboto(
                  color: AppTheme.facebookBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0),
        ),
      ),
    );
  }

  // â”€â”€ Feed de anÃºncios â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  String _feedCountLabel(int sectionIndex, int count) {
    if (sectionIndex == 4) {
      return count.toString() + (count == 1 ? ' pedido' : ' pedidos');
    }
    return count.toString() + (count == 1 ? ' an\u00FAncio' : ' an\u00FAncios');
  }

  String _feedEmptyTitle(int sectionIndex) {
    if (sectionIndex == 4) {
      return 'Nenhum pedido encontrado';
    }
    return 'Nenhum an\u00FAncio encontrado';
  }

  String _feedEmptySubtitle(int sectionIndex) {
    if (sectionIndex == 4) {
      return 'Quando algu\u00E9m publicar o que precisa, vai aparecer aqui.';
    }
    return 'Tente ajustar os filtros ou explorar outra se\u00E7\u00E3o.';
  }

  Widget _buildFeed(bool isDark, int sectionIndex) {
    if (_isLoadingAds) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.facebookBlue),
      );
    }
    final ads = _filteredAdsForSection(sectionIndex);
    if (ads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded,
                  color: Colors.grey.shade300, size: 72),
              const SizedBox(height: 16),
              Text(
                _feedEmptyTitle(sectionIndex),
                style: GoogleFonts.roboto(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _feedEmptySubtitle(sectionIndex),
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ],
          ).animate().fadeIn(),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshMarketplace,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    _feedCountLabel(sectionIndex, ads.length),
                    style: GoogleFonts.roboto(
                        color: Colors.grey,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ).animate().fadeIn(delay: 150.ms),
                  const Spacer(),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ad = ads[index];
                  return AdCard(
                    ad: ad,
                    index: index,
                    badgeLabel: _badgeLabelForAd(ad),
                    distanceKm: _roundedDistanceKmForAd(ad),
                    onTap: () {
                      context
                          .read<UserProvider>()
                          .trackCategoryClick(ad.category);
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (_, anim, __) => AdDetailScreen(ad: ad),
                          transitionsBuilder: (_, anim, __, child) =>
                              FadeTransition(opacity: anim, child: child),
                        ),
                      );
                    },
                  );
                },
                childCount: ads.length,
              ),
              gridDelegate: _marketplaceGridDelegate(context),
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Future<void> _openFiltersLegacy() async {
    final minCtrl = TextEditingController(
        text: _filters.minPrice?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(
        text: _filters.maxPrice?.toStringAsFixed(0) ?? '');
    final kmCtrl =
        TextEditingController(text: _filters.maxKm?.toString() ?? '');
    final yearMinCtrl =
        TextEditingController(text: _filters.minYear?.toString() ?? '');
    final yearMaxCtrl =
        TextEditingController(text: _filters.maxYear?.toString() ?? '');
    MarketplaceFilters temp = _filters;
    final allCategories = <String>['', ...categories];
    const manufacturers = [
      'Volkswagen',
      'Chevrolet',
      'Fiat',
      'Ford',
      'Toyota',
      'Honda',
      'Hyundai',
      'Renault',
      'Nissan',
      'Jeep',
      'Peugeot',
      'CitroÃ«n',
      'Mitsubishi',
      'BMW',
      'Mercedes-Benz',
      'Audi',
      'Kia',
      'Volvo',
      'Porsche',
      'Land Rover',
      'BYD',
      'Chery',
      'JAC',
      'Ram',
      'Suzuki',
    ];
    const fuels = [
      'Gasolina',
      'Etanol',
      'Flex',
      'Diesel',
      'ElÃ©trico',
      'HÃ­brido',
      'GNV'
    ];
    const transmissions = ['Manual', 'AutomÃ¡tico', 'CVT'];
    const vehicleFeatures = [
      'Ar-condicionado',
      'DireÃ§Ã£o hidrÃ¡ulica',
      'Airbag',
      'ABS',
      'MultimÃ­dia',
      'CÃ¢mera de rÃ©'
    ];

    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.blackCard
          : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isVehicle =
              AdModel.normalizeValue(temp.category ?? '') == 'veiculos';
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 4, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtros',
                          style: GoogleFonts.roboto(
                              fontSize: 24, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 12),
                      _dropdown<MarketplaceSort>(
                          'Classificar por',
                          temp.sort,
                          MarketplaceSort.values,
                          (v) => setModalState(
                              () => temp = temp.copyWith(sort: v!)),
                          (v) => {
                                MarketplaceSort.recommended: 'RelevÃ¢ncia',
                                MarketplaceSort.newest: 'Mais recentes',
                                MarketplaceSort.priceLow: 'Menor preÃ§o',
                                MarketplaceSort.priceHigh: 'Maior preÃ§o',
                              }[v]!),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: _input(
                                'Preço mín', minCtrl, TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: _input(
                                'Preço máx', maxCtrl, TextInputType.number)),
                      ]),
                      const SizedBox(height: 10),
                      _dropdown<PublicationDateFilter>(
                          'Data de publicação',
                          temp.publicationDate,
                          PublicationDateFilter.values,
                          (v) => setModalState(
                              () => temp = temp.copyWith(publicationDate: v!)),
                          (v) => {
                                PublicationDateFilter.any: 'Qualquer data',
                                PublicationDateFilter.last24h: 'Últimas 24h',
                                PublicationDateFilter.last7days:
                                    'Últimos 7 dias',
                                PublicationDateFilter.last30days:
                                    'Últimos 30 dias',
                              }[v]!),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                          'Condição',
                          temp.condition ?? '',
                          const ['', 'Novo', 'Seminovo', 'Usado'],
                          (v) => setModalState(() => temp = temp.copyWith(
                              condition: v,
                              resetCondition: v == null || v.isEmpty)),
                          (v) => v.isEmpty ? 'Todas' : v),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                          'Categoria',
                          temp.category ?? '',
                          allCategories,
                          (v) => setModalState(() => temp = temp.copyWith(
                              category: v,
                              resetCategory: v == null || v.isEmpty)),
                          (v) => v.isEmpty ? 'Todas' : AdModel.displayLabel(v)),
                      if (isVehicle) ...[
                        const SizedBox(height: 16),
                        Text('Filtros de veículos',
                            style: GoogleFonts.roboto(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _input('Ano mÃ­n', yearMinCtrl,
                                  TextInputType.number)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _input('Ano mÃ¡x', yearMaxCtrl,
                                  TextInputType.number)),
                        ]),
                        const SizedBox(height: 10),
                        _dropdown<String>(
                            'Fabricante',
                            temp.manufacturer ?? '',
                            const ['', ...manufacturers],
                            (v) => setModalState(() => temp = temp.copyWith(
                                manufacturer: v,
                                resetManufacturer: v == null || v.isEmpty)),
                            (v) => v.isEmpty ? 'Todos' : v),
                        const SizedBox(height: 10),
                        _dropdown<String>(
                            'Tipo de combustível',
                            temp.fuelType ?? '',
                            const ['', ...fuels],
                            (v) => setModalState(() => temp = temp.copyWith(
                                fuelType: v,
                                resetFuelType: v == null || v.isEmpty)),
                            (v) => v.isEmpty ? 'Todos' : v),
                        const SizedBox(height: 10),
                        _input('Quilometragem mÃ¡xima', kmCtrl,
                            TextInputType.number),
                        const SizedBox(height: 10),
                        _dropdown<String>(
                            'Tipo de transmissÃ£o',
                            temp.transmission ?? '',
                            const ['', ...transmissions],
                            (v) => setModalState(() => temp = temp.copyWith(
                                transmission: v,
                                resetTransmission: v == null || v.isEmpty)),
                            (v) => v.isEmpty ? 'Todos' : v),
                        const SizedBox(height: 10),
                        Text('Recursos do veículo',
                            style: GoogleFonts.roboto(
                                fontWeight: FontWeight.w600)),
                        Wrap(
                          spacing: 8,
                          children: vehicleFeatures.map((f) {
                            final selected = temp.vehicleFeatures.contains(f);
                            return FilterChip(
                              label: Text(f, style: GoogleFonts.roboto()),
                              selected: selected,
                              onSelected: (value) => setModalState(() {
                                final next =
                                    Set<String>.from(temp.vehicleFeatures);
                                value ? next.add(f) : next.remove(f);
                                temp = temp.copyWith(vehicleFeatures: next);
                              }),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                                context, MarketplaceFilters.empty),
                            child: const Text('Limpar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = temp.copyWith(
                                minPrice: double.tryParse(minCtrl.text.trim()),
                                maxPrice: double.tryParse(maxCtrl.text.trim()),
                                maxKm: int.tryParse(kmCtrl.text.trim()),
                                minYear: int.tryParse(yearMinCtrl.text.trim()),
                                maxYear: int.tryParse(yearMaxCtrl.text.trim()),
                                resetMinPrice: minCtrl.text.trim().isEmpty,
                                resetMaxPrice: maxCtrl.text.trim().isEmpty,
                                resetMaxKm: kmCtrl.text.trim().isEmpty,
                                resetMinYear: yearMinCtrl.text.trim().isEmpty,
                                resetMaxYear: yearMaxCtrl.text.trim().isEmpty,
                              );
                              Navigator.pop(context, parsed);
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ]),
                    ]),
              ),
            ),
          );
        },
      ),
    );
    if (result != null) setState(() => _filters = result);
  }

  Future<void> _openFilters() async {
    final minCtrl = TextEditingController(
      text: _filters.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: _filters.maxPrice?.toStringAsFixed(0) ?? '',
    );
    final kmCtrl =
        TextEditingController(text: _filters.maxKm?.toString() ?? '');
    final yearMinCtrl = TextEditingController(
      text: _filters.minYear?.toString() ?? '',
    );
    final yearMaxCtrl = TextEditingController(
      text: _filters.maxYear?.toString() ?? '',
    );
    MarketplaceFilters temp = _filters;
    final allCategories = <String>['', ...categories];
    const typeOptions = ['', AdModel.productType, AdModel.serviceType];
    const propertyOfferOptions = [
      '',
      AdModel.propertyOfferSale,
      AdModel.propertyOfferRent,
    ];
    const manufacturers = [
      'Volkswagen',
      'Chevrolet',
      'Fiat',
      'Ford',
      'Toyota',
      'Honda',
      'Hyundai',
      'Renault',
      'Nissan',
      'Jeep',
      'Peugeot',
      'Citroen',
      'Mitsubishi',
      'BMW',
      'Mercedes-Benz',
      'Audi',
      'Kia',
      'Volvo',
      'Porsche',
      'Land Rover',
      'BYD',
      'Chery',
      'JAC',
      'Ram',
      'Suzuki',
    ];
    const fuels = [
      'Gasolina',
      'Etanol',
      'Flex',
      'Diesel',
      'Eletrico',
      'Hibrido',
      'GNV',
    ];
    const vehicleFeatures = [
      'Ar-condicionado',
      'Direcao hidraulica',
      'Airbag',
      'ABS',
      'Multimidia',
      'Camera de re',
    ];

    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.blackCard
          : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedCategory =
              AdModel.resolveCategoryValue(temp.category ?? '');
          final normalizedCategory = AdModel.normalizeValue(selectedCategory);
          final selectedType = temp.adType ?? '';
          final isProductContext =
              selectedType.isEmpty || selectedType == AdModel.productType;
          final isVehicle =
              normalizedCategory == 'veiculos' && isProductContext;
          final isProperty =
              normalizedCategory == 'imoveis' && isProductContext;

          void clearVehicleFilters() {
            kmCtrl.clear();
            yearMinCtrl.clear();
            yearMaxCtrl.clear();
            temp = temp.copyWith(
              manufacturer: '',
              fuelType: '',
              transmission: '',
              vehicleFeatures: <String>{},
              resetManufacturer: true,
              resetFuelType: true,
              resetTransmission: true,
              resetMaxKm: true,
              resetMinYear: true,
              resetMaxYear: true,
            );
          }

          void syncDependentFilters() {
            final currentCategory = AdModel.normalizeValue(
              AdModel.resolveCategoryValue(temp.category ?? ''),
            );
            final currentType = temp.adType ?? '';
            final currentIsProductContext =
                currentType.isEmpty || currentType == AdModel.productType;

            if (!(currentCategory == 'veiculos' && currentIsProductContext)) {
              clearVehicleFilters();
            }
            if (!(currentCategory == 'imoveis' && currentIsProductContext)) {
              temp = temp.copyWith(
                propertyOfferType: '',
                resetPropertyOfferType: true,
              );
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros',
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _dropdown<MarketplaceSort>(
                      'Classificar por',
                      temp.sort,
                      MarketplaceSort.values,
                      (v) => setModalState(
                        () => temp = temp.copyWith(sort: v!),
                      ),
                      (v) => {
                        MarketplaceSort.recommended: 'Relevância',
                        MarketplaceSort.newest: 'Mais recentes',
                        MarketplaceSort.priceLow: 'Menor preço',
                        MarketplaceSort.priceHigh: 'Maior preço',
                      }[v]!,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            'Preço mín',
                            minCtrl,
                            TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _input(
                            'Preço máx',
                            maxCtrl,
                            TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown<PublicationDateFilter>(
                      'Data de publicação',
                      temp.publicationDate,
                      PublicationDateFilter.values,
                      (v) => setModalState(
                        () => temp = temp.copyWith(publicationDate: v!),
                      ),
                      (v) => {
                        PublicationDateFilter.any: 'Qualquer data',
                        PublicationDateFilter.last24h: 'Últimas 24h',
                        PublicationDateFilter.last7days: 'Últimos 7 dias',
                        PublicationDateFilter.last30days: 'Últimos 30 dias',
                      }[v]!,
                    ),
                    const SizedBox(height: 10),
                    _dropdown<String>(
                      'Tipo',
                      temp.adType ?? '',
                      typeOptions,
                      (v) => setModalState(() {
                        temp = temp.copyWith(
                          adType: v,
                          resetAdType: v == null || v.isEmpty,
                        );
                        syncDependentFilters();
                      }),
                      (v) => v.isEmpty ? 'Todos' : AdModel.displayLabel(v),
                    ),
                    const SizedBox(height: 10),
                    _dropdown<String>(
                      'Categoria',
                      temp.category ?? '',
                      allCategories,
                      (v) => setModalState(() {
                        temp = temp.copyWith(
                          category: v,
                          resetCategory: v == null || v.isEmpty,
                        );
                        syncDependentFilters();
                      }),
                      (v) => v.isEmpty ? 'Todas' : AdModel.displayLabel(v),
                    ),
                    if (isProperty) ...[
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Negócio',
                        temp.propertyOfferType ?? '',
                        propertyOfferOptions,
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            propertyOfferType: v,
                            resetPropertyOfferType: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : AdModel.displayLabel(v),
                      ),
                    ],
                    if (isVehicle) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Filtros de veículos',
                        style: GoogleFonts.roboto(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _input(
                              'Ano mín',
                              yearMinCtrl,
                              TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _input(
                              'Ano máx',
                              yearMaxCtrl,
                              TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Fabricante',
                        temp.manufacturer ?? '',
                        const ['', ...manufacturers],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            manufacturer: v,
                            resetManufacturer: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : v,
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Tipo de combustível',
                        temp.fuelType ?? '',
                        const ['', ...fuels],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            fuelType: v,
                            resetFuelType: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : AdModel.displayLabel(v),
                      ),
                      const SizedBox(height: 10),
                      _input(
                        'Quilometragem máxima',
                        kmCtrl,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Recursos do veículo',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: vehicleFeatures.map((feature) {
                          final selected =
                              temp.vehicleFeatures.contains(feature);
                          return FilterChip(
                            label: Text(
                              AdModel.displayLabel(feature),
                              style: GoogleFonts.roboto(),
                            ),
                            selected: selected,
                            onSelected: (value) => setModalState(() {
                              final next =
                                  Set<String>.from(temp.vehicleFeatures);
                              value ? next.add(feature) : next.remove(feature);
                              temp = temp.copyWith(vehicleFeatures: next);
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              MarketplaceFilters.empty,
                            ),
                            child: const Text('Limpar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = temp.copyWith(
                                minPrice: double.tryParse(minCtrl.text.trim()),
                                maxPrice: double.tryParse(maxCtrl.text.trim()),
                                maxKm: int.tryParse(kmCtrl.text.trim()),
                                minYear: int.tryParse(yearMinCtrl.text.trim()),
                                maxYear: int.tryParse(yearMaxCtrl.text.trim()),
                                resetMinPrice: minCtrl.text.trim().isEmpty,
                                resetMaxPrice: maxCtrl.text.trim().isEmpty,
                                resetMaxKm: kmCtrl.text.trim().isEmpty,
                                resetMinYear: yearMinCtrl.text.trim().isEmpty,
                                resetMaxYear: yearMaxCtrl.text.trim().isEmpty,
                              );
                              Navigator.pop(context, parsed);
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _filters = result);
    }
  }

  Widget _input(String label, TextEditingController controller,
      TextInputType keyboardType) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
    );
  }

  Widget _dropdown<T>(String label, T value, List<T> values,
      ValueChanged<T?> onChanged, String Function(T) labelBuilder) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      onChanged: onChanged,
      decoration:
          InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: values
          .map((v) => DropdownMenuItem(
              value: v,
              child: Text(labelBuilder(v), overflow: TextOverflow.ellipsis)))
          .toList(),
    );
  }

  // â”€â”€ Categorias â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Eletronicos':
        return Icons.devices_rounded;
      case 'Veiculos':
        return Icons.directions_car_rounded;
      case 'Imoveis':
        return Icons.home_rounded;
      case 'Moveis':
        return Icons.chair_rounded;
      case 'Roupas':
        return Icons.checkroom_rounded;
      case 'Esportes':
        return Icons.sports_soccer_rounded;
      case 'Animais':
      case 'Servicos pet':
        return Icons.pets_rounded;
      case 'Assistencia tecnica':
        return Icons.build_circle_rounded;
      case 'Aulas e cursos':
        return Icons.school_rounded;
      case 'Beleza e estetica':
        return Icons.content_cut_rounded;
      case 'Consultoria':
        return Icons.support_agent_rounded;
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
        return Icons.health_and_safety_rounded;
      case 'Vaga de emprego':
        return Icons.work_outline_rounded;
      case 'Outros servicos':
        return Icons.miscellaneous_services_rounded;
      default:
        return Icons.sell_rounded;
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Eletronicos':
        return const Color(0xFF1877F2);
      case 'Veiculos':
        return const Color(0xFFE74C3C);
      case 'Imoveis':
        return const Color(0xFF27AE60);
      case 'Moveis':
        return const Color(0xFFE67E22);
      case 'Roupas':
        return const Color(0xFF9B59B6);
      case 'Esportes':
        return const Color(0xFF2ECC71);
      case 'Animais':
      case 'Servicos pet':
        return const Color(0xFF795548);
      case 'Assistencia tecnica':
        return const Color(0xFF2563EB);
      case 'Aulas e cursos':
        return const Color(0xFF0EA5E9);
      case 'Beleza e estetica':
        return const Color(0xFFEC4899);
      case 'Consultoria':
        return const Color(0xFF4F46E5);
      case 'Design e marketing':
        return const Color(0xFFF97316);
      case 'Eventos':
        return const Color(0xFFEF4444);
      case 'Fretes e mudancas':
        return const Color(0xFF14B8A6);
      case 'Limpeza':
        return const Color(0xFF06B6D4);
      case 'Reformas e manutencao':
        return const Color(0xFFB45309);
      case 'Saude e bem-estar':
        return const Color(0xFF10B981);
      case 'Outros servicos':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF607D8B);
    }
  }

  Widget _buildCategoriesGrid(bool isDark) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900
        ? 5
        : width >= 700
            ? 4
            : width >= 460
                ? 3
                : 2;

    return RefreshIndicator(
      onRefresh: _refreshMarketplace,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 124,
        ),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final category = categories[i];
          final icon = _categoryIcon(category);
          final color = _categoryColor(category);
          return GestureDetector(
            onTap: () {
              // Rastreia interesse
              context.read<UserProvider>().trackCategoryClick(category);
              // Navega para tela da categoria
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryAdsScreen(
                    category: category,
                    icon: icon,
                    locationScope: _locationScope,
                    locationRegionKey: _locationRegionKey,
                    searchLat: _searchLat,
                    searchLng: _searchLng,
                    searchRadiusKm: _searchRadiusKm,
                    locationLabel: _locationLabel,
                  ),
                ),
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.blackCard : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AdModel.displayLabel(category),
                    style: GoogleFonts.roboto(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
                .animate(delay: Duration(milliseconds: i * 50))
                .fadeIn(duration: 300.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                ),
          );
        },
      ),
    );
  }

  // â”€â”€ Drawer â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildDrawer(bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = context.watch<UserProvider>().user;
    final bg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? AppTheme.whiteSecondary : Colors.grey.shade600;

    return Container(
      width: 312,
      height: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        border: Border(left: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(-4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      _toggleDrawer();
                      _handleAuthRequired(
                        () => setState(() => _selectedNavIndex = 4),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 58,
                            height: 58,
                            child: ClipOval(
                              child: user?.profilePhoto != null
                                  ? Image.network(
                                      user!.profilePhoto!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: AppTheme.facebookBlue.withValues(
                                          alpha: 0.12,
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          color: AppTheme.facebookBlue,
                                          size: 30,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppTheme.facebookBlue.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: const Icon(
                                        Icons.person_rounded,
                                        color: AppTheme.facebookBlue,
                                        size: 30,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user == null
                                      ? 'Sua conta'
                                      : '${user.firstName} ${user.lastName}'
                                          .trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.sora(
                                    color: textColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.email ??
                                      'Entre para personalizar sua vitrine',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.manrope(
                                    color: subColor,
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                if (user != null)
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _firestore.getReviewsForUser(
                                      user.uid,
                                    ),
                                    builder: (context, snapshot) {
                                      final reviews = snapshot.data ?? const [];
                                      if (reviews.isEmpty) {
                                        return Text(
                                          'Sem avaliações',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.manrope(
                                            color: subColor,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        );
                                      }

                                      final total = reviews.fold<double>(
                                        0,
                                        (sum, review) =>
                                            sum +
                                            ((review['rating'] as num?)
                                                    ?.toDouble() ??
                                                0),
                                      );
                                      final average = total / reviews.length;

                                      return Row(
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Color(0xFFFFB800),
                                            size: 16,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              '${average.toStringAsFixed(1)} (${reviews.length} avaliações)',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.manrope(
                                                color: subColor,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Divider(color: border, height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      themeProvider.isDarkMode
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: subColor,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Text('Modo escuro',
                        style: GoogleFonts.roboto(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Switch(
                      value: themeProvider.isDarkMode,
                      onChanged: (_) => themeProvider.toggleTheme(),
                      activeThumbColor: AppTheme.facebookBlue,
                    ),
                  ],
                ),
              ),
              Divider(color: border, height: 1),
              _drawerItem(Icons.person_outline_rounded, 'Meu Perfil', textColor,
                  subColor,
                  onTap: () => _handleAuthRequired(
                        () => setState(() => _selectedNavIndex = 4),
                      )),
              _drawerItem(
                  Icons.store_outlined, 'Minhas Lojas', textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MyStoresScreen()),
                      ))),
              _drawerItem(
                  Icons.sell_outlined, 'Meus Anúncios', textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MyAdsScreen()),
                      ))),
              _drawerItem(Icons.favorite_outline_rounded, 'Favoritos',
                  textColor, subColor,
                  onTap: () => _handleAuthRequired(() {
                        setState(() => _selectedNavIndex = 0);
                        _setSelectedSection(6);
                      })),
              _drawerItem(Icons.chat_bubble_outline_rounded, 'Mensagens',
                  textColor, subColor,
                  onTap: () => _handleAuthRequired(
                      () => setState(() => _selectedNavIndex = 3))),
              _drawerItem(
                  Icons.settings_outlined, 'Configurações', textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ))),
              _drawerItem(Icons.reviews_outlined, 'Avaliações para responder',
                  textColor, subColor,
                  onTap: user == null
                      ? () => _handleAuthRequired(() {})
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ReviewsScreen(
                                userId: user.uid,
                                title: 'Avaliações',
                                allowReply: true,
                              ),
                            ),
                          )),
              _drawerItem(Icons.history_rounded, 'Vistos recentemente',
                  textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RecentlyViewedScreen()),
                      ))),
              _drawerItem(Icons.group_outlined, 'Seguidores do marketplace',
                  textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FollowNetworkScreen(
                            title: 'Seguidores do marketplace',
                            followersMode: true,
                          ),
                        ),
                      ))),
              _drawerItem(Icons.person_add_alt_1_outlined, 'Seguindo',
                  textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FollowNetworkScreen(
                            title: 'Seguindo',
                            followersMode: false,
                          ),
                        ),
                      ))),
              _drawerItem(Icons.insights_outlined, 'Atividades de venda',
                  textColor, subColor,
                  onTap: () => _handleAuthRequired(() => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SalesActivityScreen()),
                      ))),
              const SizedBox(height: 20),
              Divider(color: border, height: 1),
              _drawerItem(Icons.logout_rounded, 'Sair', Colors.red, Colors.red,
                  isDestructive: true, onTap: () async {
                await AuthService().logout();
                if (mounted) {
                  context.read<UserProvider>().clear();
                  setState(() => _selectedNavIndex = 4);
                }
              }),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Image.asset(
                    isDark
                        ? 'assets/images/logo_completo_cv_dk.png'
                        : 'assets/images/logo_completo_cv.png',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerItem(
    IconData icon,
    String label,
    Color textColor,
    Color iconColor, {
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: () {
        _toggleDrawer();
        if (onTap != null) onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.roboto(
                  color: textColor,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (!isDestructive)
              Icon(Icons.chevron_right_rounded,
                  color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  // â”€â”€ Bottom Nav â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildBottomNav(bool isDark) {
    final bg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0);
    const active = AppTheme.facebookBlue;
    final inactive = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;

    final items = [
      {'icon': Icons.home_rounded, 'label': 'Início'},
      {'icon': Icons.search_rounded, 'label': 'Buscar'},
      null, // botÃ£o +
      {'icon': Icons.chat_bubble_outline_rounded, 'label': 'Chat'},
      {'icon': Icons.person_outline_rounded, 'label': 'Perfil'},
    ];

    return Container(
      height: 75,
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          if (items[index] == null) {
            return Expanded(
              child: InkWell(
                onTap: () => _handleAuthRequired(() {
                  if (_isDrawerOpen) {
                    _toggleDrawer();
                  }
                  _openCreateAd();
                }),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppTheme.facebookBlue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.facebookBlue.withValues(alpha: 0.35),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
              ),
            );
          }

          final item = items[index]!;
          final isActive = _selectedNavIndex == index;

          return Expanded(
            child: InkWell(
              onTap: () {
                if (index == 3) {
                  _handleAuthRequired(() {
                    if (_isDrawerOpen) {
                      _toggleDrawer();
                    }
                    setState(() => _selectedNavIndex = index);
                  });
                  return;
                }

                if (_isDrawerOpen) {
                  _toggleDrawer();
                }
                setState(() => _selectedNavIndex = index);
                if (index == 0) _setSelectedSection(0);
                if (index == 1) _openSearch();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? active.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      item['icon'] as IconData,
                      color: isActive ? active : inactive,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['label'] as String,
                    style: GoogleFonts.roboto(
                      color: isActive ? active : inactive,
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _openCreateAd() async {
    final intent =
        _selectedSection == 4 ? AdModel.intentBuy : AdModel.intentSell;
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => CreateAdScreen(initialIntent: intent),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    );
    // Recarrega os anÃºncios se um novo foi criado
    _loadAds();
  }

  // ignore: unused_element
  void _showNotifications(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.blackCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
            const SizedBox(height: 24),
            Text('NotificaÃ§Ãµes',
                style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 60),
            Icon(Icons.notifications_none_rounded,
                size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Nenhuma notificaÃ§Ã£o',
                style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
