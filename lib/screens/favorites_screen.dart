import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'ad_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _firestore = FirestoreService();
  List<AdModel> _ads = [];
  bool _loading = true;

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
    final ads = await _firestore.getFavoriteAds(user.favoriteAdIds);
    if (mounted) setState(() { _ads = ads; _loading = false; });
  }

  Future<void> _removeFavorite(AdModel ad) async {
    final uid = context.read<UserProvider>().uid!;
    await _firestore.toggleFavorite(uid, ad.id, add: false);
    await context.read<UserProvider>().refresh();
    setState(() => _ads.removeWhere((a) => a.id == ad.id));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removido dos favoritos', style: GoogleFonts.outfit(color: Colors.white)),
          backgroundColor: Colors.grey.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Desfazer',
            textColor: Colors.white,
            onPressed: () async {
              await _firestore.toggleFavorite(uid, ad.id, add: true);
              await context.read<UserProvider>().refresh();
              setState(() => _ads.insert(0, ad));
            },
          ),
        ),
      );
    }
  }

  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(2).split('.');
    final buffer = StringBuffer();
    int count = 0;
    for (int i = parts[0].length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(parts[0][i]);
      count++;
    }
    return 'R\$ ${buffer.toString().split('').reversed.join('')},${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;

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
          style: GoogleFonts.outfit(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (!_loading && _ads.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${_ads.length} ${_ads.length == 1 ? 'item' : 'itens'}',
                style: GoogleFonts.outfit(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : _ads.isEmpty
              ? _buildEmpty(isDark, textColor)
              : RefreshIndicator(
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
                        formatPrice: _formatPrice,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad)),
                        ),
                        onRemove: () => _removeFavorite(ad),
                      ).animate(delay: Duration(milliseconds: i * 50)).fadeIn().scale(
                          begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
                    },
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
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_outline_rounded,
                color: Colors.red, size: 44),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'Nenhum favorito ainda',
            style: GoogleFonts.outfit(
                color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'Salve anúncios que te interessam\ne encontre-os facilmente aqui.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14, height: 1.5),
          ).animate(delay: 160.ms).fadeIn(),
        ],
      ),
    );
  }
}

class _FavCard extends StatelessWidget {
  final AdModel ad;
  final bool isDark;
  final Color cardBg, border, textColor, mutedColor;
  final String Function(double) formatPrice;
  final VoidCallback onTap, onRemove;

  const _FavCard({
    required this.ad,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.formatPrice,
    required this.onTap,
    required this.onRemove,
  });

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
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagem
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Container(
                      width: double.infinity,
                      color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                      child: ad.images.isNotEmpty
                          ? Image.network(ad.images.first, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _placeholder())
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
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.red, size: 18),
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
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(ad.price),
                    style: GoogleFonts.outfit(
                      color: AppTheme.facebookBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: mutedColor, size: 11),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          ad.location,
                          style: GoogleFonts.outfit(color: mutedColor, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
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
      child: Icon(Icons.sell_outlined,
          color: isDark ? Colors.white12 : Colors.grey.shade300, size: 36),
    );
  }
}