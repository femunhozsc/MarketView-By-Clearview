import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/store_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import '../models/ad_model.dart';

class MyStoreScreen extends StatefulWidget {
  const MyStoreScreen({super.key});

  @override
  State<MyStoreScreen> createState() => _MyStoreScreenState();
}

class _MyStoreScreenState extends State<MyStoreScreen> {
  final _firestoreService = FirestoreService();
  StoreModel? _store;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStore();
  }

  Future<void> _loadStore() async {
    final user = context.read<UserProvider>().user;
    if (user == null || user.storeId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    final store = await _firestoreService.getStore(user.storeId!);
    if (mounted) setState(() { _store = store; _loading = false; });
  }

  Future<void> _toggleStoreStatus() async {
    if (_store == null) return;
    final newStatus = !_store!.isActive;
    await _firestoreService.updateStore(_store!.id, {'isActive': newStatus});
    setState(() => _store = _store!.copyWith(isActive: newStatus));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus ? 'Loja ativada' : 'Loja pausada',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          backgroundColor: newStatus ? AppTheme.success : Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
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
          'Minha loja',
          style: GoogleFonts.outfit(color: textColor, fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue))
          : _store == null
              ? _buildNoStore(isDark, textColor)
              : RefreshIndicator(
                  onRefresh: _loadStore,
                  color: AppTheme.facebookBlue,
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // Banner
                      _buildBanner(isDark, cardBg),

                      const SizedBox(height: 48),

                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (_store!.isActive ? AppTheme.success : Colors.orange)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(
                                          color: _store!.isActive ? AppTheme.success : Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _store!.isActive ? 'Loja ativa' : 'Loja pausada',
                                        style: GoogleFonts.outfit(
                                          color: _store!.isActive ? AppTheme.success : Colors.orange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(),

                            const SizedBox(height: 12),

                            Text(
                              _store!.name,
                              style: GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ).animate(delay: 60.ms).fadeIn(),

                            const SizedBox(height: 4),

                            Text(
                              _store!.category,
                              style: GoogleFonts.outfit(
                                color: AppTheme.facebookBlue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ).animate(delay: 80.ms).fadeIn(),

                            const SizedBox(height: 12),

                            Text(
                              _store!.description,
                              style: GoogleFonts.outfit(
                                color: mutedColor,
                                fontSize: 14,
                                height: 1.6,
                              ),
                            ).animate(delay: 100.ms).fadeIn(),

                            const SizedBox(height: 20),

                            // Endereço
                            _infoCard(
                              isDark: isDark,
                              cardBg: cardBg,
                              border: border,
                              icon: Icons.location_on_outlined,
                              iconColor: AppTheme.facebookBlue,
                              title: 'Endereço',
                              value: _store!.address.formatted,
                              textColor: textColor,
                              mutedColor: mutedColor,
                            ).animate(delay: 140.ms).fadeIn(),

                            const SizedBox(height: 12),

                            // Avaliação
                            _infoCard(
                              isDark: isDark,
                              cardBg: cardBg,
                              border: border,
                              icon: Icons.star_rounded,
                              iconColor: Colors.orange,
                              title: 'Avaliação',
                              value: '${_store!.rating.toStringAsFixed(1)} ⭐  '
                                  '(${_store!.totalReviews} avaliações)',
                              textColor: textColor,
                              mutedColor: mutedColor,
                            ).animate(delay: 160.ms).fadeIn(),

                            const SizedBox(height: 24),

                            // Ações
                            _sectionLabel('Gerenciar loja', isDark),
                            const SizedBox(height: 10),

                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: border),
                              ),
                              child: Column(
                                children: [
                                  _actionTile(
                                    icon: _store!.isActive
                                        ? Icons.pause_circle_outline_rounded
                                        : Icons.play_circle_outline_rounded,
                                    iconColor: _store!.isActive ? Colors.orange : AppTheme.success,
                                    label: _store!.isActive ? 'Pausar loja' : 'Ativar loja',
                                    subtitle: _store!.isActive
                                        ? 'Anúncios ficam ocultos temporariamente'
                                        : 'Seus anúncios voltam a aparecer',
                                    textColor: textColor,
                                    onTap: _toggleStoreStatus,
                                  ),
                                  Divider(height: 1, indent: 66, color: border),
                                  _actionTile(
                                    icon: Icons.edit_outlined,
                                    iconColor: AppTheme.facebookBlue,
                                    label: 'Editar informações',
                                    subtitle: 'Nome, descrição, logo e banner',
                                    textColor: textColor,
                                    onTap: () {
                                      // Navegar para edição da loja
                                    },
                                  ),
                                  Divider(height: 1, indent: 66, color: border),
                                  _actionTile(
                                    icon: Icons.add_circle_outline_rounded,
                                    iconColor: const Color(0xFF27AE60),
                                    label: 'Adicionar produto / serviço',
                                    subtitle: 'Publique novos anúncios',
                                    textColor: textColor,
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ],
                              ),
                            ).animate(delay: 200.ms).fadeIn(),

                            const SizedBox(height: 32),

                            _sectionLabel('Produtos e Serviços', isDark),
                            const SizedBox(height: 16),

                            FutureBuilder<List<AdModel>>(
                              future: _firestoreService.getAdsByStore(_store!.id),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator(color: AppTheme.facebookBlue));
                                }
                                final ads = snapshot.data ?? [];
                                if (ads.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 40),
                                      child: Column(
                                        children: [
                                          Icon(Icons.inventory_2_outlined, color: mutedColor.withOpacity(0.3), size: 48),
                                          const SizedBox(height: 12),
                                          Text('Nenhum produto cadastrado', style: GoogleFonts.outfit(color: mutedColor)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: 0.75,
                                  ),
                                  itemCount: ads.length,
                                  itemBuilder: (context, index) => AdCard(
                                    ad: ads[index],
                                    index: index,
                                    onTap: () {
                                      // Navegar para detalhe
                                    },
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBanner(bool isDark, Color cardBg) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 180,
          width: double.infinity,
          color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
          child: _store?.banner != null
              ? Image.network(_store!.banner!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _bannerPlaceholder())
              : _bannerPlaceholder(),
        ),
        Positioned(
          bottom: -40,
          left: 16,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: isDark ? AppTheme.black : Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: ClipOval(
              child: _store?.logo != null
                  ? Image.network(_store!.logo!, fit: BoxFit.cover)
                  : Center(child: Text(_store?.name[0] ?? 'S', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.facebookBlue))),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bannerPlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.store_rounded, color: AppTheme.facebookBlue, size: 52),
          const SizedBox(height: 8),
          Text(
            _store?.name ?? '',
            style: GoogleFonts.outfit(
              color: AppTheme.facebookBlue, fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildNoStore(bool isDark, Color textColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(
                color: AppTheme.facebookBlue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.store_outlined,
                  color: AppTheme.facebookBlue, size: 44),
            ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text('Você ainda não tem loja',
                style: GoogleFonts.outfit(
                    color: textColor, fontSize: 18, fontWeight: FontWeight.w700)
            ).animate(delay: 100.ms).fadeIn(),
            const SizedBox(height: 8),
            Text(
              'Crie sua loja para ter uma presença profissional e alcançar mais clientes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14, height: 1.5),
            ).animate(delay: 160.ms).fadeIn(),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.facebookBlue,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.facebookBlue.withOpacity(0.3),
                      blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Text('Criar minha loja',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ).animate(delay: 220.ms).fadeIn().slideY(begin: 0.1, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required bool isDark,
    required Color cardBg,
    required Color border,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color textColor,
    required Color mutedColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(
                    color: mutedColor, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value, style: GoogleFonts.outfit(
                    color: textColor, fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.outfit(
        color: isDark ? AppTheme.whiteMuted : Colors.grey.shade500,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: GoogleFonts.outfit(
                      color: textColor, fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(subtitle, style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }
}