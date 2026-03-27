import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import 'ad_detail_screen.dart';
import 'category_ads_screen.dart';
import 'seller_profile_screen.dart';

// Tela "Ver Mais Recomendados" com scroll infinito
class AllRecommendedScreen extends StatefulWidget {
  final List<String> topCategories;
  const AllRecommendedScreen({super.key, required this.topCategories});

  @override
  State<AllRecommendedScreen> createState() => _AllRecommendedScreenState();
}

class _AllRecommendedScreenState extends State<AllRecommendedScreen> {
  final _firestore = FirestoreService();
  final _scrollCtrl = ScrollController();
  List<AdModel> _ads = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

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
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 300) {
      if (!_loadingMore && _hasMore) _loadMore();
    }
  }

  Future<void> _loadAds() async {
    setState(() => _loading = true);
    final result = await _firestore.getRecommendedAdsPaginated(
      widget.topCategories,
      limit: 20,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87, size: 22),
          ),
        ),
        title: Text(
          'Recomendados para você',
          style: GoogleFonts.outfit(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8)),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : CustomScrollView(
              controller: _scrollCtrl,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(12),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final ad = _ads[i];
                        return AdCard(
                          ad: ad,
                          index: i,
                          onTap: () {
                            _firestore.incrementAdClick(ad.id);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad)),
                            );
                          },
                        );
                      },
                      childCount: _ads.length,
                    ),
                  ),
                ),
                if (_loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue)),
                    ),
                  ),
                if (!_hasMore && _ads.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Você viu todos os recomendados!',
                          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
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

// ─────────────────────────────────────────────────────────────────────────────

class ForYouScreen extends StatefulWidget {
  final VoidCallback? onViewMoreStores;

  const ForYouScreen({super.key, this.onViewMoreStores});

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  final FirestoreService _firestore = FirestoreService();
  final ScrollController _scrollController = ScrollController();

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

  // Ordem padrão de categorias para novos usuários
  static const List<String> _defaultCategoryOrder = [
    'Eletrônicos', 'Veículos', 'Imóveis', 'Móveis', 'Roupas',
    'Esportes', 'Design', 'Educação', 'Saúde', 'Beleza', 'Animais', 'Outros',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialData();
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

  Future<void> _loadInitialData() async {
    final user = context.read<UserProvider>().user;

    // Determina se é novo usuário e define categorias
    if (user != null && user.categoryClicks.isNotEmpty) {
      _isNewUser = false;
      // Usuário com interesses: coloca as categorias favoritas primeiro
      final topCats = user.topCategories;
      final remaining = _defaultCategoryOrder.where((c) => !topCats.contains(c)).toList();
      _userCategories = [...topCats, ...remaining];
    } else {
      _isNewUser = true;
      _userCategories = List.from(_defaultCategoryOrder);
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
        // Novo usuário: mostra os mais populares (mais clicados)
        recommended = await _firestore.getPopularAds(limit: 6);
        // Se não há anúncios populares suficientes, completa com os mais recentes
        if (recommended.length < 6) {
          final recent = await _firestore.getAds(limit: 6 - recommended.length);
          final existingIds = recommended.map((a) => a.id).toSet();
          recommended.addAll(recent.where((a) => !existingIds.contains(a.id)));
        }
      } else {
        // Usuário com interesses: busca pelas top 3 categorias
        final topCats = _userCategories.take(3).toList();
        for (final cat in topCats) {
          final ads = await _firestore.getAdsByCategory(cat, limit: 2);
          recommended.addAll(ads);
        }
        // Completa com populares se necessário
        if (recommended.length < 6) {
          final popular = await _firestore.getPopularAds(limit: 6 - recommended.length);
          final existingIds = recommended.map((a) => a.id).toSet();
          recommended.addAll(popular.where((a) => !existingIds.contains(a.id)));
        }
      }

      if (mounted) {
        setState(() {
          _recommendedAds = recommended.take(6).toList();
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
      final ads = await _firestore.getAdsByCategory(category, limit: 6);
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

  void _navigateToAd(AdModel ad) {
    // Rastreia o clique na categoria
    context.read<UserProvider>().trackCategoryClick(ad.category);
    _firestore.incrementAdClick(ad.id);
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = context.watch<UserProvider>().user;
    final userName = user?.firstName ?? 'Visitante';

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── Header "Olá, Usuário!" ──────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Olá, $userName!',
                  style: GoogleFonts.outfit(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1, end: 0),
                const SizedBox(height: 4),
                Text(
                  _isNewUser
                      ? 'Confira os anúncios mais populares do momento'
                      : 'Selecionamos esses anúncios para você',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: isDark ? AppTheme.whiteMuted : Colors.grey.shade600,
                  ),
                ).animate(delay: 100.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
        ),

        // ── Recomendados (6 cards em grid) ──────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        _loadingRecommended
            ? const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppTheme.facebookBlue),
                  ),
                ),
              )
            : _recommendedAds.isEmpty
                ? SliverToBoxAdapter(
                    child: _emptyState(
                      'Nenhum anúncio disponível ainda',
                      'Seja o primeiro a anunciar no MarketView!',
                      Icons.auto_awesome_rounded,
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => AdCard(
                          ad: _recommendedAds[index],
                          index: index,
                          onTap: () => _navigateToAd(_recommendedAds[index]),
                        ),
                        childCount: _recommendedAds.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.68,
                      ),
                    ),
                  ),

        // ── Botão "Ver mais recomendados" ───────────────────────
        if (!_loadingRecommended && _recommendedAds.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllRecommendedScreen(
                        topCategories: _isNewUser ? [] : _userCategories.take(3).toList(),
                      ),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.facebookBlue),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Ver mais recomendados',
                  style: GoogleFonts.outfit(
                    color: AppTheme.facebookBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ).animate(delay: 200.ms).fadeIn(),
            ),
          ),

        // ── Seção "Lojas Destaque" ──────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lojas Destaque',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onViewMoreStores,
                  child: Text(
                    'Ver mais',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.facebookBlue,
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

        // ── Categorias por interesse (lazy loaded) ──────────────
        ..._buildCategorySections(isDark),

        // ── Loading indicator para mais categorias ──────────────
        if (_loadingMoreCategories)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue)),
            ),
          ),

        // Espaçamento final
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── Carrossel de Lojas ──────────────────────────────────────────────────
  Widget _buildStoresCarousel(bool isDark) {
    if (_loadingStores) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue)),
      );
    }

    if (_featuredStores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Text(
          'Nenhuma loja cadastrada no momento',
          style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    return SizedBox(
      height: 148,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // Mostra todas as lojas + botão "ver mais" no final
        itemCount: _featuredStores.length + 1,
        itemBuilder: (context, index) {
          if (index == _featuredStores.length) {
            // Botão "Ver mais" no final do carrossel
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: widget.onViewMoreStores,
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.facebookBlue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded, color: AppTheme.facebookBlue, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ver mais',
                        style: GoogleFonts.outfit(
                          color: AppTheme.facebookBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerProfileScreen(
                      sellerId: store.ownerId,
                      sellerName: store.name,
                    ),
                  ),
                );
              },
              child: Container(
                width: 104,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.blackCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
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
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.facebookBlue.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: store.logo != null
                            ? Image.network(
                                store.logo!,
                                fit: BoxFit.cover,
                                width: 54,
                                height: 54,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.facebookBlue.withOpacity(0.1),
                                  child: const Icon(Icons.store_rounded, color: AppTheme.facebookBlue, size: 26),
                                ),
                              )
                            : Container(
                                color: AppTheme.facebookBlue.withOpacity(0.1),
                                child: const Icon(Icons.store_rounded, color: AppTheme.facebookBlue, size: 26),
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Nome da loja
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        store.name,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
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
                        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 13),
                        const SizedBox(width: 2),
                        Text(
                          store.rating > 0 ? store.rating.toStringAsFixed(1) : 'Novo',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.whiteMuted : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ).animate(delay: Duration(milliseconds: index * 40))
                .fadeIn(duration: 300.ms)
                .slideX(begin: 0.15, end: 0),
          );
        },
      ),
    );
  }

  // ── Seções de Categorias ────────────────────────────────────────────────
  List<Widget> _buildCategorySections(bool isDark) {
    final widgets = <Widget>[];

    for (int i = 0; i < _loadedCategoryIndex && i < _userCategories.length; i++) {
      final category = _userCategories[i];
      final ads = _categoryAds[category];

      if (ads == null || ads.isEmpty) continue;

      // Título da categoria
      widgets.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.facebookBlue.withOpacity(0.1),
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
                      category,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _navigateToCategory(category),
                  child: Text(
                    'Ver mais',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.facebookBlue,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) => AdCard(
                ad: ads[index],
                index: index,
                onTap: () => _navigateToAd(ads[index]),
              ),
              childCount: ads.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.68,
            ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: isDark ? AppTheme.blackBorder : Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Ver mais em $category',
                style: GoogleFonts.outfit(
                  color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
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
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Eletrônicos': return Icons.devices_rounded;
      case 'Veículos': return Icons.directions_car_rounded;
      case 'Imóveis': return Icons.home_rounded;
      case 'Móveis': return Icons.chair_rounded;
      case 'Roupas': return Icons.checkroom_rounded;
      case 'Esportes': return Icons.sports_soccer_rounded;
      case 'Design': return Icons.design_services_rounded;
      case 'Educação': return Icons.school_rounded;
      case 'Saúde': return Icons.health_and_safety_rounded;
      case 'Beleza': return Icons.face_retouching_natural_rounded;
      case 'Animais': return Icons.pets_rounded;
      default: return Icons.sell_rounded;
    }
  }
}
