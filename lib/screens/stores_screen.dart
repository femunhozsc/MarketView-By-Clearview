import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/store_list_card.dart';
import 'seller_profile_screen.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({
    super.key,
    required this.stores,
    required this.isLoading,
    required this.onRefresh,
    required this.locationScope,
    required this.locationRegionKey,
    required this.searchLat,
    required this.searchLng,
    required this.searchRadiusKm,
    required this.locationLabel,
  });

  final List<StoreModel> stores;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final String locationScope;
  final String locationRegionKey;
  final double searchLat;
  final double searchLng;
  final int searchRadiusKm;
  final String locationLabel;

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  static const int _pageSize = 6;
  static const List<String> _defaultInterestOrder = [
    'Eletronicos',
    'Veiculos',
    'Imoveis',
    'Moveis',
    'Roupas',
    'Esportes',
    'Design',
    'Educacao',
    'Saude',
    'Beleza',
    'Animais',
    'Alimentacao',
    'Servicos Gerais',
    'Outros',
  ];

  final ScrollController _scrollController = ScrollController();
  final Distance _distance = const Distance();
  int _visibleRecommendedCount = _pageSize;
  int _loadedCategorySectionCount = 1;
  final Map<String, int> _visibleCountByCategory = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant StoresScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stores != widget.stores ||
        oldWidget.locationScope != widget.locationScope ||
        oldWidget.locationRegionKey != widget.locationRegionKey ||
        oldWidget.searchLat != widget.searchLat ||
        oldWidget.searchLng != widget.searchLng ||
        oldWidget.searchRadiusKm != widget.searchRadiusKm ||
        oldWidget.locationLabel != widget.locationLabel) {
      _visibleRecommendedCount = _pageSize;
      _loadedCategorySectionCount = 1;
      _visibleCountByCategory.clear();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 320) {
      return;
    }

    final user = context.read<UserProvider>().user;
    final categoryCount = _orderedInterestCategories(user).length;
    if (_loadedCategorySectionCount >= categoryCount) return;
    setState(() => _loadedCategorySectionCount++);
  }

  String _normalize(String value) => AdModel.normalizeValue(value);

  List<String> _aliasesForCategory(String category) {
    final normalized = _normalize(category);
    const aliases = <String, List<String>>{
      'animais': ['animais', 'pets', 'pet'],
      'eletronicos': ['eletronicos', 'eletronico'],
      'veiculos': ['veiculos', 'veiculo', 'automoveis'],
      'imoveis': ['imoveis', 'imovel'],
      'moveis': ['moveis', 'movel'],
      'alimentacao': ['alimentacao', 'alimentos', 'comida'],
      'servicos gerais': ['servicos gerais', 'servicos', 'servico'],
    };
    return aliases[normalized] ?? [normalized];
  }

  bool _categoryMatchesStore(String interestCategory, StoreModel store) {
    return _categoryMatchesValue(interestCategory, store.category);
  }

  bool _categoryMatchesValue(
      String interestCategory, String storeCategoryValue) {
    final storeCategory = _normalize(storeCategoryValue);
    return _aliasesForCategory(interestCategory).any(
      (alias) => storeCategory.contains(alias) || alias.contains(storeCategory),
    );
  }

  double? _distanceKmForStore(StoreModel store) {
    if (store.address.lat == null || store.address.lng == null) return null;
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(widget.searchLat, widget.searchLng),
      LatLng(store.address.lat!, store.address.lng!),
    );
  }

  List<StoreModel> get _visibleStores {
    final seen = <String>{};
    return widget.stores.where((store) {
      if (!store.isActive) return false;
      if (seen.contains(store.id)) return false;
      seen.add(store.id);
      return true;
    }).toList();
  }

  double _recommendationScore(StoreModel store, UserModel? user) {
    final topCategories = user?.topCategories ?? const <String>[];
    final interestIndex = topCategories.indexWhere(
      (category) => _categoryMatchesStore(category, store),
    );

    var score = 0.0;
    if (interestIndex >= 0) {
      score += 140 - (interestIndex * 22);
    }
    if (user?.followingSellerIds.contains(store.ownerId) ?? false) {
      score += 18;
    }
    if (user?.favoriteStoreIds.contains(store.id) ?? false) {
      score += 14;
    }

    final distanceKm = _distanceKmForStore(store);
    if (distanceKm != null) {
      score += (120 - distanceKm).clamp(0, 120);
    }

    score += store.rating * 24;
    score += store.totalReviews.clamp(0, 80).toDouble();
    score += store.createdAt.millisecondsSinceEpoch / 1000000000000;
    return score;
  }

  List<StoreModel> _recommendedStores(UserModel? user) {
    final ranked = [..._visibleStores]..sort(
        (a, b) => _recommendationScore(b, user).compareTo(
          _recommendationScore(a, user),
        ),
      );

    final stronglyRated = ranked
        .where((store) => store.totalReviews > 0 && store.rating >= 4.5)
        .toList();

    // Quando as lojas tiverem avaliações reais, priorizamos rating >= 4.5 no topo.
    if (stronglyRated.isEmpty) return ranked;

    final strongIds = stronglyRated.map((store) => store.id).toSet();
    return [
      ...ranked.where((store) => strongIds.contains(store.id)),
      ...ranked.where((store) => !strongIds.contains(store.id)),
    ];
  }

  List<String> _orderedInterestCategories(UserModel? user) {
    final topCategories = user?.topCategories ?? const <String>[];
    final availableCategories = _visibleStores
        .map((store) => store.category)
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList();

    availableCategories.sort();

    final ordered = <String>[];
    for (final interest in topCategories) {
      for (final category in availableCategories) {
        if (!ordered.contains(category) &&
            _categoryMatchesValue(interest, category)) {
          ordered.add(category);
        }
      }
    }

    for (final fallback in _defaultInterestOrder) {
      for (final category in availableCategories) {
        if (!ordered.contains(category) &&
            _categoryMatchesValue(fallback, category)) {
          ordered.add(category);
        }
      }
    }

    for (final category in availableCategories) {
      if (!ordered.contains(category)) ordered.add(category);
    }
    return ordered;
  }

  List<StoreModel> _storesForCategory(String category, UserModel? user) {
    final stores = _visibleStores
        .where((store) => _categoryMatchesStore(category, store))
        .toList()
      ..sort(
        (a, b) => _recommendationScore(b, user).compareTo(
          _recommendationScore(a, user),
        ),
      );
    return stores;
  }

  void _openStore(StoreModel store) {
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
  }

  void _showMoreRecommended() {
    setState(() {
      _visibleRecommendedCount = (_visibleRecommendedCount + _pageSize).clamp(
          0, _recommendedStores(context.read<UserProvider>().user).length);
    });
  }

  void _showMoreCategory(String category, int totalCount) {
    final current = _visibleCountByCategory[category] ?? _pageSize;
    setState(() {
      _visibleCountByCategory[category] =
          (current + _pageSize).clamp(0, totalCount);
    });
  }

  Widget _buildSectionHeader({
    required String title,
    String? subtitle,
    IconData? icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppTheme.facebookBlue),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color:
                    isDark ? AppTheme.whiteSecondary : const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _iconForCategory(String category) {
    final normalized = _normalize(category);
    if (normalized.contains('veiculo')) return Icons.directions_car_rounded;
    if (normalized.contains('animal') || normalized.contains('pet')) {
      return Icons.pets_rounded;
    }
    if (normalized.contains('eletron')) return Icons.devices_rounded;
    if (normalized.contains('imove')) return Icons.home_work_rounded;
    if (normalized.contains('roupa')) return Icons.checkroom_rounded;
    if (normalized.contains('esporte')) return Icons.sports_soccer_rounded;
    if (normalized.contains('saude')) return Icons.favorite_rounded;
    if (normalized.contains('beleza')) return Icons.spa_rounded;
    if (normalized.contains('educa')) return Icons.school_rounded;
    if (normalized.contains('aliment')) return Icons.restaurant_rounded;
    if (normalized.contains('servico')) return Icons.handyman_rounded;
    return Icons.storefront_rounded;
  }

  Widget _buildSeeMoreButton({
    required String label,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
          side: BorderSide(
            color: isDark ? AppTheme.blackBorder : const Color(0xFFD9E1EA),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppTheme.facebookBlue,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCategorySections() {
    final user = context.watch<UserProvider>().user;
    final slivers = <Widget>[];
    final visibleSections =
        _orderedInterestCategories(user).take(_loadedCategorySectionCount);

    for (final category in visibleSections) {
      final stores = _storesForCategory(category, user);
      if (stores.isEmpty) continue;

      final visibleCount = _visibleCountByCategory[category] ?? _pageSize;
      final visibleStores = stores.take(visibleCount).toList();

      slivers.add(
        SliverToBoxAdapter(
          child: _buildSectionHeader(
            title: AdModel.displayLabel(category),
            icon: _iconForCategory(category),
          ),
        ),
      );

      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final store = visibleStores[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  0,
                  12,
                  0,
                ),
                child: StoreListCard(
                  store: store,
                  onTap: () => _openStore(store),
                  showDivider: index != visibleStores.length - 1,
                ),
              );
            },
            childCount: visibleStores.length,
          ),
        ),
      );

      if (visibleCount < stores.length) {
        slivers.add(
          SliverToBoxAdapter(
            child: _buildSeeMoreButton(
              label: 'Ver mais de ${AdModel.displayLabel(category)}',
              onTap: () => _showMoreCategory(category, stores.length),
            ),
          ),
        );
      }
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppTheme.black : Colors.white;
    final user = context.watch<UserProvider>().user;
    final recommended = _recommendedStores(user);
    final visibleRecommended = recommended
        .take(_visibleRecommendedCount.clamp(0, recommended.length))
        .toList();

    if (widget.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.facebookBlue),
      );
    }

    if (_visibleStores.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ColoredBox(
          color: backgroundColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 140),
              Icon(Icons.storefront_outlined,
                  color: Colors.grey.shade300, size: 72),
              const SizedBox(height: 16),
              Text(
                'Nenhuma loja encontrada no momento',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ColoredBox(
        color: backgroundColor,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                title: 'Lojas Recomendadas',
                subtitle: 'De acordo com o seus interesses',
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final store = visibleRecommended[index];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: StoreListCard(
                      store: store,
                      onTap: () => _openStore(store),
                      showDivider: index != visibleRecommended.length - 1,
                    ),
                  );
                },
                childCount: visibleRecommended.length,
              ),
            ),
            if (_visibleRecommendedCount < recommended.length)
              SliverToBoxAdapter(
                child: _buildSeeMoreButton(
                  label: 'Ver mais recomendadas',
                  onTap: _showMoreRecommended,
                ),
              ),
            ..._buildCategorySections(),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}
