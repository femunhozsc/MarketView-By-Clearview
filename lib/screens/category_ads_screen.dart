import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import '../widgets/marketplace_controls.dart';
import 'ad_detail_screen.dart';
import 'favorites_screen.dart';

class CategoryAdsScreen extends StatefulWidget {
  final String category;
  final IconData icon;
  final bool ignoreLocationFilter;
  final String locationScope;
  final String locationRegionKey;
  final double searchLat;
  final double searchLng;
  final int searchRadiusKm;
  final String locationLabel;

  const CategoryAdsScreen({
    super.key,
    required this.category,
    required this.icon,
    this.ignoreLocationFilter = false,
    this.locationScope = 'city',
    this.locationRegionKey = '',
    this.searchLat = 0,
    this.searchLng = 0,
    this.searchRadiusKm = 50,
    this.locationLabel = '',
  });

  @override
  State<CategoryAdsScreen> createState() => _CategoryAdsScreenState();
}

class _CategoryAdsScreenState extends State<CategoryAdsScreen> {
  final _firestore = FirestoreService();
  final _scrollCtrl = ScrollController();
  final Distance _distance = const Distance();

  List<AdModel> _ads = [];
  MarketplaceFilters _filters = MarketplaceFilters.empty;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  String _normalize(String value) => AdModel.normalizeValue(value);
  String get _resolvedCategory => AdModel.resolveCategoryValue(widget.category);
  bool get _isPropertyCategory =>
      AdModel.normalizeValue(_resolvedCategory) == 'imoveis';

  double? _distanceKmForAd(AdModel ad) {
    if (widget.searchLat == 0 ||
        widget.searchLng == 0 ||
        ad.lat == null ||
        ad.lng == null) {
      return null;
    }

    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(widget.searchLat, widget.searchLng),
      LatLng(ad.lat!, ad.lng!),
    );
  }

  bool _matchesStateLocation(AdModel ad) {
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

    final normalizedLocation = _normalize(ad.location);
    final aliases = aliasesByState[_normalize(widget.locationRegionKey)] ??
        [_normalize(widget.locationRegionKey)];

    return aliases.any(
      (alias) =>
          normalizedLocation.contains(', $alias') ||
          normalizedLocation.endsWith(alias) ||
          normalizedLocation.contains(alias),
    );
  }

  bool _matchesSelectedLocation(AdModel ad) {
    if (widget.ignoreLocationFilter) return true;

    final hasExplicitLocation = widget.searchLat != 0 ||
        widget.searchLng != 0 ||
        widget.locationLabel.trim().isNotEmpty ||
        widget.locationRegionKey.trim().isNotEmpty;
    if (!hasExplicitLocation) return true;
    if (widget.locationScope == 'country') return true;
    if (widget.locationScope == 'state') return _matchesStateLocation(ad);

    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm != null) {
      return distanceKm <= widget.searchRadiusKm;
    }

    final selectedRegion = _normalize(
      widget.locationLabel.replaceFirst(RegExp(r'\s+[|\-]\s+\d+\s*km$'), ''),
    );
    final adLocation = _normalize(ad.location);
    if (selectedRegion.isEmpty) return true;
    if (adLocation.isEmpty) return false;
    return adLocation.contains(selectedRegion) ||
        selectedRegion.contains(adLocation);
  }

  int? _roundedDistanceKmForAd(AdModel ad) {
    if (widget.ignoreLocationFilter) return null;
    if (widget.locationScope != 'city') return null;
    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm == null) return null;
    if (distanceKm > 0 && distanceKm < 1) return 1;
    return distanceKm.round();
  }

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

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _loading = true);
    try {
      final result = await _firestore.getAdsByCategoryPaginated(
        _resolvedCategory,
        limit: 20,
        intent: AdModel.intentSell,
      );
      final ads = result['ads'] as List<AdModel>;
      if (mounted) {
        setState(() {
          _ads = ads;
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = ads.length == 20;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _firestore.getAdsByCategoryPaginated(
        _resolvedCategory,
        limit: 20,
        startAfter: _lastDoc,
        intent: AdModel.intentSell,
      );
      final newAds = result['ads'] as List<AdModel>;
      if (mounted) {
        setState(() {
          _ads.addAll(newAds);
          _lastDoc = result['lastDoc'] as DocumentSnapshot?;
          _hasMore = newAds.length == 20;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final filteredAds = _applyFilters(_ads);

    return Scaffold(
      backgroundColor: bg,
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
            child: Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: AppTheme.facebookBlue, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              AdModel.displayLabel(_resolvedCategory),
              style: GoogleFonts.roboto(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : _ads.isEmpty || filteredAds.isEmpty
              ? _buildEmpty(isDark, textColor)
              : RefreshIndicator(
                  onRefresh: _loadAds,
                  color: AppTheme.facebookBlue,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    slivers: [
                      SliverToBoxAdapter(
                        child: MarketplaceLocationActions(
                          locationLabel: widget.locationLabel.isEmpty
                              ? 'Resultados em ${AdModel.displayLabel(_resolvedCategory)}'
                              : widget.locationLabel,
                          onLocationTap: () {},
                          compact: true,
                          onFiltersTap: _openSimpleFilters,
                          onSavedTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FavoritesScreen()),
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 0, 24),
                        sliver: SliverGrid(
                          gridDelegate: _gridDelegate(context),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final ad = filteredAds[i];
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
                                distanceKm: _roundedDistanceKmForAd(ad),
                                onTap: () {
                                  context
                                      .read<UserProvider>()
                                      .trackCategoryClick(ad.category);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdDetailScreen(ad: ad),
                                    ),
                                  );
                                },
                              );
                            },
                            childCount: filteredAds.length,
                          ),
                        ),
                      ),
                      if (_loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.facebookBlue),
                            ),
                          ),
                        ),
                      if (!_hasMore && _ads.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'Você viu todos os anúncios de ${AdModel.displayLabel(_resolvedCategory)}',
                                style: GoogleFonts.roboto(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEmpty(bool isDark, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, color: AppTheme.facebookBlue, size: 44),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'Nenhum anúncio em ${AdModel.displayLabel(_resolvedCategory)}',
            style: GoogleFonts.roboto(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'Seja o primeiro a anunciar nesta categoria!',
            style: GoogleFonts.roboto(color: Colors.grey, fontSize: 14),
          ).animate(delay: 160.ms).fadeIn(),
        ],
      ),
    );
  }

  List<AdModel> _applyFilters(List<AdModel> source) {
    final filtered = source.where((ad) {
      if (!_matchesSelectedLocation(ad)) return false;
      return _filters.matchesAd(ad);
    }).toList();
    if (widget.locationScope == 'city') {
      filtered.sort((a, b) {
        final aDistance = _distanceKmForAd(a) ?? double.infinity;
        final bDistance = _distanceKmForAd(b) ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
    }
    if (_filters.sort == MarketplaceSort.priceLow) {
      filtered.sort((a, b) => a.price.compareTo(b.price));
    }
    if (_filters.sort == MarketplaceSort.priceHigh) {
      filtered.sort((a, b) => b.price.compareTo(a.price));
    }
    if (_filters.sort == MarketplaceSort.newest) {
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return filtered;
  }

  // ignore: unused_element
  Future<void> _openSimpleFiltersLegacy() async {
    final minCtrl = TextEditingController(
        text: _filters.minPrice?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(
        text: _filters.maxPrice?.toStringAsFixed(0) ?? '');
    MarketplaceSort sort = _filters.sort;
    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<MarketplaceSort>(
            initialValue: sort,
            decoration: const InputDecoration(
                labelText: 'Classificar por', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(
                  value: MarketplaceSort.recommended,
                  child: Text('Relevância')),
              DropdownMenuItem(
                  value: MarketplaceSort.newest, child: Text('Mais recentes')),
              DropdownMenuItem(
                  value: MarketplaceSort.priceLow, child: Text('Menor preço')),
              DropdownMenuItem(
                  value: MarketplaceSort.priceHigh, child: Text('Maior preço')),
            ],
            onChanged: (v) => sort = v ?? MarketplaceSort.recommended,
          ),
          const SizedBox(height: 10),
          TextField(
              controller: minCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Preço mín', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
              controller: maxCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Preço máx', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              context,
              MarketplaceFilters(
                sort: sort,
                minPrice: double.tryParse(minCtrl.text.trim()),
                maxPrice: double.tryParse(maxCtrl.text.trim()),
              ),
            ),
            child: const Text('Aplicar'),
          ),
        ]),
      ),
    );
    if (result != null) setState(() => _filters = result);
  }

  Future<void> _openSimpleFilters() async {
    final minCtrl = TextEditingController(
      text: _filters.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: _filters.maxPrice?.toStringAsFixed(0) ?? '',
    );
    MarketplaceSort sort = _filters.sort;
    String selectedType = _filters.adType ?? '';
    String selectedPropertyOffer = _filters.propertyOfferType ?? '';

    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final isPropertyFilterVisible =
              _isPropertyCategory && selectedType != AdModel.serviceType;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<MarketplaceSort>(
                  initialValue: sort,
                  decoration: const InputDecoration(
                    labelText: 'Classificar por',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: MarketplaceSort.recommended,
                      child: Text('Relevância'),
                    ),
                    DropdownMenuItem(
                      value: MarketplaceSort.newest,
                      child: Text('Mais recentes'),
                    ),
                    DropdownMenuItem(
                      value: MarketplaceSort.priceLow,
                      child: Text('Menor preço'),
                    ),
                    DropdownMenuItem(
                      value: MarketplaceSort.priceHigh,
                      child: Text('Maior preço'),
                    ),
                  ],
                  onChanged: (v) => setModalState(
                      () => sort = v ?? MarketplaceSort.recommended),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Todos')),
                    DropdownMenuItem(
                      value: AdModel.productType,
                      child: Text('Produto'),
                    ),
                    DropdownMenuItem(
                      value: AdModel.serviceType,
                      child: Text('Serviço'),
                    ),
                  ],
                  onChanged: (value) => setModalState(() {
                    selectedType = value ?? '';
                    if (selectedType == AdModel.serviceType) {
                      selectedPropertyOffer = '';
                    }
                  }),
                ),
                if (isPropertyFilterVisible) ...[
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedPropertyOffer,
                    decoration: const InputDecoration(
                      labelText: 'Negócio',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Todos')),
                      DropdownMenuItem(
                        value: AdModel.propertyOfferSale,
                        child: Text('Venda'),
                      ),
                      DropdownMenuItem(
                        value: AdModel.propertyOfferRent,
                        child: Text('Aluguel'),
                      ),
                    ],
                    onChanged: (value) => setModalState(
                      () => selectedPropertyOffer = value ?? '',
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Preço mín',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Preço máx',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    MarketplaceFilters(
                      sort: sort,
                      minPrice: double.tryParse(minCtrl.text.trim()),
                      maxPrice: double.tryParse(maxCtrl.text.trim()),
                      adType: selectedType.isEmpty ? null : selectedType,
                      propertyOfferType: selectedPropertyOffer.isEmpty
                          ? null
                          : selectedPropertyOffer,
                    ),
                  ),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _filters = result);
    }
  }
}
