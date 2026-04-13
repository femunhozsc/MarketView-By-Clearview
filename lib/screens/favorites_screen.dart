import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/store_list_card.dart';
import 'ad_detail_screen.dart';
import 'seller_profile_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _firestore = FirestoreService();
  List<AdModel> _ads = [];
  List<StoreModel> _stores = [];
  bool _loading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);
    final results = await Future.wait([
      _firestore.getFavoriteAds(user.favoriteAdIds),
      _firestore.getFavoriteStores(user.favoriteStoreIds),
    ]);

    if (mounted) {
      setState(() {
        _ads = results[0] as List<AdModel>;
        _stores = results[1] as List<StoreModel>;
        _loading = false;
      });
    }
  }

  Future<void> _removeFavoriteAd(AdModel ad) async {
    final userProvider = context.read<UserProvider>();
    final uid = userProvider.uid!;
    await _firestore.toggleFavorite(uid, ad.id, add: false);
    await userProvider.refresh();
    if (!mounted) return;
    setState(() => _ads.removeWhere((item) => item.id == ad.id));
  }

  Future<void> _removeFavoriteStore(StoreModel store) async {
    final userProvider = context.read<UserProvider>();
    await userProvider.toggleFavoriteStore(store.id);
    if (!mounted) return;
    setState(() => _stores.removeWhere((item) => item.id == store.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final textColor = isDark ? Colors.white : Colors.black87;
    final totalCount = _selectedTab == 0 ? _ads.length : _stores.length;

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
        title: Text(
          'Favoritos',
          style: GoogleFonts.roboto(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (!_loading)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$totalCount ${totalCount == 1 ? 'item' : 'itens'}',
                  style: GoogleFonts.roboto(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _FavoriteSectionToggle(
                    label: 'Anuncios',
                    selected: _selectedTab == 0,
                    onTap: () => setState(() => _selectedTab = 0),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _FavoriteSectionToggle(
                    label: 'Lojas',
                    selected: _selectedTab == 1,
                    onTap: () => setState(() => _selectedTab = 1),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.facebookBlue,
                    ),
                  )
                : _selectedTab == 0
                    ? _buildAdsTab(isDark, textColor)
                    : _buildStoresTab(textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAdsTab(bool isDark, Color textColor) {
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;

    if (_ads.isEmpty) {
      return _buildEmpty(
        icon: Icons.favorite_outline_rounded,
        title: 'Nenhum anuncio favorito ainda',
        subtitle: 'Salve anuncios para encontrar tudo aqui depois.',
        textColor: textColor,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppTheme.facebookBlue,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.72,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _ads.length,
        itemBuilder: (_, i) {
          final ad = _ads[i];
          return _FavCard(
            ad: ad,
            isDark: isDark,
            cardBg: cardBg,
            border: border,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad)),
            ),
            onRemove: () => _removeFavoriteAd(ad),
          ).animate(delay: Duration(milliseconds: i * 45)).fadeIn().scale(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
              );
        },
      ),
    );
  }

  Widget _buildStoresTab(Color textColor) {
    if (_stores.isEmpty) {
      return _buildEmpty(
        icon: Icons.storefront_outlined,
        title: 'Nenhuma loja favorita ainda',
        subtitle: 'Toque no coracao das lojas para salvar suas preferidas.',
        textColor: textColor,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: AppTheme.facebookBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _stores.length,
        itemBuilder: (_, i) {
          final store = _stores[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Dismissible(
              key: ValueKey('favorite-store-${store.id}'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white),
              ),
              onDismissed: (_) => _removeFavoriteStore(store),
              child: StoreListCard(
                store: store,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerProfileScreen(
                      sellerId: store.ownerId,
                      sellerName: store.name,
                      storeId: store.id,
                    ),
                  ),
                ),
              ),
            ),
          ).animate(delay: Duration(milliseconds: i * 40)).fadeIn();
        },
      ),
    );
  }

  Widget _buildEmpty({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.red, size: 44),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.roboto(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.roboto(
              color: Colors.grey,
              fontSize: 14,
              height: 1.5,
            ),
          ).animate(delay: 160.ms).fadeIn(),
        ],
      ),
    );
  }
}

class _FavoriteSectionToggle extends StatelessWidget {
  const _FavoriteSectionToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.facebookBlue
              : (isDark ? AppTheme.blackCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppTheme.facebookBlue
                : (isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white : const Color(0xFF334155)),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  const _FavCard({
    required this.ad,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
    required this.onRemove,
  });

  final AdModel ad;
  final bool isDark;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: isDark
                          ? AppTheme.blackLight
                          : const Color(0xFFF0F2F5),
                      child: ad.images.isNotEmpty
                          ? Image.network(
                              ad.images.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder(),
                            )
                          : _placeholder(),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Colors.red,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.roboto(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ad.displayPriceLabel,
                    style: GoogleFonts.roboto(
                      color: AppTheme.facebookBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          color: mutedColor, size: 11),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          ad.location,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.roboto(
                            color: mutedColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Colors.grey.shade400,
        size: 34,
      ),
    );
  }
}
