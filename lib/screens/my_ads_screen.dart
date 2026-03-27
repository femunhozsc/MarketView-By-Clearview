import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'edit_ad_screen.dart';

class MyAdsScreen extends StatefulWidget {
  const MyAdsScreen({super.key});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> with TickerProviderStateMixin {
  final _firestore = FirestoreService();
  List<AdModel> _personalAds = [];
  List<AdModel> _storeAds = [];
  bool _loading = true;
  int _selectedTab = 0; // 0 = Pessoal, 1 = Loja

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  Future<void> _loadAds() async {
    final user = context.read<UserProvider>().user;
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    
    setState(() => _loading = true);
    
    // Carrega anúncios pessoais
    final personal = await _firestore.getPersonalAdsByUser(user.uid);
    
    // Carrega anúncios da loja se o usuário tiver uma
    List<AdModel> store = [];
    if (user.hasStore && user.storeId != null) {
      store = await _firestore.getAdsByStore(user.storeId!);
    }
    
    if (mounted) {
      setState(() {
        _personalAds = personal;
        _storeAds = store;
        _loading = false;
      });
    }
  }

  Future<void> _deleteAd(AdModel ad) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Excluir anúncio',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          content: Text('Tem certeza que deseja excluir "${ad.title}"?',
              style: GoogleFonts.outfit()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Excluir',
                  style: GoogleFonts.outfit(color: AppTheme.error, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await _firestore.deleteAd(ad.id);
      setState(() {
        _personalAds.removeWhere((a) => a.id == ad.id);
        _storeAds.removeWhere((a) => a.id == ad.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anúncio excluído', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
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

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _typeColor(String type) {
    switch (type) {
      case 'servico': return const Color(0xFF9B59B6);
      default: return AppTheme.facebookBlue;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'servico': return 'Serviço';
      default: return 'Produto';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;
    
    final user = context.watch<UserProvider>().user;
    final hasStore = user?.hasStore ?? false;
    final currentAds = _selectedTab == 0 ? _personalAds : _storeAds;
    final tabCount = hasStore ? 2 : 1;

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
          'Meus anúncios',
          style: GoogleFonts.outfit(
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
                color: AppTheme.facebookBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${currentAds.length} ${currentAds.length == 1 ? 'anúncio' : 'anúncios'}',
                style: GoogleFonts.outfit(
                  color: AppTheme.facebookBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : Column(
              children: [
                // ── Abas (Pessoal / Loja) ──────────────────────────
                if (tabCount > 1)
                  Container(
                    color: isDark ? AppTheme.blackCard : Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 0),
                            child: Column(
                              children: [
                                Text(
                                  'Pessoal',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.w500,
                                    color: _selectedTab == 0 ? AppTheme.facebookBlue : mutedColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 0 ? AppTheme.facebookBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedTab = 1),
                            child: Column(
                              children: [
                                Text(
                                  'Loja',
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.w500,
                                    color: _selectedTab == 1 ? AppTheme.facebookBlue : mutedColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: _selectedTab == 1 ? AppTheme.facebookBlue : Colors.transparent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // ── Lista de Anúncios ──────────────────────────────
                Expanded(
                  child: currentAds.isEmpty
                      ? _buildEmpty(isDark, textColor)
                      : RefreshIndicator(
                          onRefresh: _loadAds,
                          color: AppTheme.facebookBlue,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: currentAds.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final ad = currentAds[i];
                              return _AdCard(
                                ad: ad,
                                isDark: isDark,
                                cardBg: cardBg,
                                border: border,
                                textColor: textColor,
                                mutedColor: mutedColor,
                                formatPrice: _formatPrice,
                                formatDate: _formatDate,
                                typeColor: _typeColor,
                                typeLabel: _typeLabel,
                                onEdit: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EditAdScreen(ad: ad)),
                                ).then((_) => _loadAds()),
                                onDelete: () => _deleteAd(ad),
                              ).animate(delay: Duration(milliseconds: i * 60)).fadeIn().slideY(begin: 0.1, end: 0);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmpty(bool isDark, Color textColor) {
    final tabName = _selectedTab == 0 ? 'pessoais' : 'da loja';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.facebookBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sell_outlined,
                color: AppTheme.facebookBlue, size: 44),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text(
            'Nenhum anúncio $tabName',
            style: GoogleFonts.outfit(
                color: textColor, fontSize: 18, fontWeight: FontWeight.w700),
          ).animate(delay: 100.ms).fadeIn(),
          const SizedBox(height: 8),
          Text(
            'Seus anúncios $tabName\naparecerão aqui.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14, height: 1.5),
          ).animate(delay: 160.ms).fadeIn(),
        ],
      ),
    );
  }
}

class _AdCard extends StatelessWidget {
  final AdModel ad;
  final bool isDark;
  final Color cardBg, border, textColor, mutedColor;
  final String Function(double) formatPrice;
  final String Function(DateTime) formatDate;
  final Color Function(String) typeColor;
  final String Function(String) typeLabel;
  final VoidCallback onEdit, onDelete;

  const _AdCard({
    required this.ad,
    required this.isDark,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.formatPrice,
    required this.formatDate,
    required this.typeColor,
    required this.typeLabel,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
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
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: Container(
                height: 140,
                width: double.infinity,
                color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                child: ad.images.isNotEmpty
                    ? Image.network(ad.images.first, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : _placeholder(),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: typeColor(ad.type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          typeLabel(ad.type),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        formatDate(ad.createdAt),
                        style: GoogleFonts.outfit(color: mutedColor, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ad.title,
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatPrice(ad.price),
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white : const Color(0xFF4A4A4A),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: mutedColor, size: 14),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          ad.location,
                          style: GoogleFonts.outfit(color: mutedColor, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded,
                                  color: AppTheme.error, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Excluir',
                                style: GoogleFonts.outfit(
                                  color: AppTheme.error,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
        Icons.sell_outlined,
        color: isDark ? Colors.white12 : Colors.grey.shade300,
        size: 48,
      ),
    );
  }
}
