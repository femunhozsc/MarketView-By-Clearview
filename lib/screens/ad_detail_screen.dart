import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/ad_model.dart';
import '../providers/user_provider.dart';
import '../theme/app_theme.dart';
import 'chat_detail_screen.dart';
import 'my_store_screen.dart';
import 'seller_profile_screen.dart';
import '../services/firestore_service.dart';
import '../widgets/favorite_button.dart';

class AdDetailScreen extends StatefulWidget {
  final AdModel ad;

  const AdDetailScreen({super.key, required this.ad});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {

  String _formatPrice(double price) {
    final parts = price.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(intPart[i]);
      count++;
    }
    final formatted = buffer.toString().split('').reversed.join('');
    return 'R\$ $formatted,$decPart';
  }

  void _showContactOptions(BuildContext context, String sellerId) async {
    final firestore = FirestoreService();
    final seller = await firestore.getUser(sellerId);
    
    if (seller == null || seller.phone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vendedor não informou telefone de contato.'))
        );
      }
      return;
    }

    final phone = seller.phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: isDark ? AppTheme.blackCard : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Entre em contato',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              _contactBtn(
                icon: Icons.chat_rounded,
                label: 'Enviar WhatsApp',
                color: const Color(0xFF25D366),
                onTap: () => launchUrl(Uri.parse('https://wa.me/55$phone?text=Olá, vi seu anúncio "${widget.ad.title}" no MarketView!')),
              ),
              const SizedBox(height: 12),
              _contactBtn(
                icon: Icons.phone_rounded,
                label: 'Ligar agora',
                color: AppTheme.facebookBlue,
                onTap: () => launchUrl(Uri.parse('tel:$phone')),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      );
    }
  }

  Widget _contactBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  String _formatKm(int km) {
    final buffer = StringBuffer();
    final s = km.toString();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
      count++;
    }
    return '${buffer.toString().split('').reversed.join('')} km';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

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
      default: return Icons.sell_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'servico': return const Color(0xFF9B59B6);
      case 'loja': return const Color(0xFF27AE60);
      default: return AppTheme.facebookBlue;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'servico': return 'Serviço';
      case 'loja': return 'Loja';
      default: return 'Produto';
    }
  }

  int _currentImgIndex = 0;
  final _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    // Rastreia clique ao abrir o anúncio
    if (widget.ad.id.isNotEmpty) {
      _firestoreService.incrementAdClick(widget.ad.id);
    }
  }

  void _openFullScreenGallery(BuildContext context, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenGallery(
          images: widget.ad.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;
    final imgBg = isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5);
    final isVehicle = widget.ad.category == 'Veículos';

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── AppBar com imagem ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: isDark ? AppTheme.black : Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FavoriteButton(
                    adId: widget.ad.id,
                    size: 36,
                    showBackground: false,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {},
                child: Container(
                  margin: const EdgeInsets.only(right: 10, top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.share_rounded,
                        color: Colors.white, size: 22),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.ad.images.isNotEmpty
                  ? Stack(
                      children: [
                        PageView.builder(
                          itemCount: widget.ad.images.length,
                          onPageChanged: (i) => setState(() => _currentImgIndex = i),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openFullScreenGallery(context, index),
                              child: Hero(
                                tag: 'ad_img_${widget.ad.id}_$index',
                                child: Image.network(
                                  widget.ad.images[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: imgBg,
                                    child: const Icon(Icons.broken_image_outlined, size: 50),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        if (widget.ad.images.length > 1)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_currentImgIndex + 1}/${widget.ad.images.length}',
                                style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Container(
                      color: imgBg,
                      child: Center(
                        child: Icon(
                          _getCategoryIcon(widget.ad.category),
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                          size: 100,
                        ),
                      ),
                    ),
            ),
          ),

          // ── Conteúdo ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Card principal
                Container(
                  width: double.infinity,
                  color: cardBg,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tag tipo
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getTypeColor(widget.ad.type),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getTypeLabel(widget.ad.type),
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms),

                      const SizedBox(height: 12),

                      // Título
                      Row(
                        children: [
                          if (widget.ad.storeId != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(Icons.store_rounded, color: AppTheme.facebookBlue, size: 24),
                            ),
                          Expanded(
                            child: Text(
                              widget.ad.title,
                              style: GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 80.ms),

                      const SizedBox(height: 10),

                      // Preço
                      Builder(
                        builder: (context) {
                          if (widget.ad.oldPrice != null) {
                            return Row(
                              children: [
                                Text(
                                  _formatPrice(widget.ad.oldPrice!),
                                  style: GoogleFonts.outfit(
                                    color: Colors.grey,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatPrice(widget.ad.price),
                                  style: GoogleFonts.outfit(
                                    color: isDark ? Colors.white : const Color(0xFF4A4A4A),
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ).animate().fadeIn(delay: 120.ms);
                          }
                          return Text(
                            _formatPrice(widget.ad.price),
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white : const Color(0xFF4A4A4A),
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                            ),
                          ).animate().fadeIn(delay: 120.ms);
                        },
                      ),

                      const SizedBox(height: 14),

                      // Infos rápidas
                      SizedBox(
                        width: double.infinity,
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            _infoChip(
                              icon: Icons.location_on_outlined,
                              label: widget.ad.location,
                              isDark: isDark,
                              border: border,
                            ),
                            _infoChip(
                              icon: Icons.access_time_rounded,
                              label: _formatDate(widget.ad.createdAt),
                              isDark: isDark,
                              border: border,
                            ),
                            _infoChip(
                              icon: Icons.category_outlined,
                              label: widget.ad.category,
                              isDark: isDark,
                              border: border,
                            ),
                            if (isVehicle && widget.ad.km != null)
                              _infoChip(
                                icon: Icons.speed_rounded,
                                label: _formatKm(widget.ad.km!),
                                isDark: isDark,
                                border: border,
                                highlight: true,
                              ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 160.ms),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // Descrição
                Container(
                  width: double.infinity,
                  color: cardBg,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Descrição',
                        style: GoogleFonts.outfit(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          widget.ad.description,
                          style: GoogleFonts.outfit(
                            color: mutedColor,
                            fontSize: 15,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 8),

                // Vendedor
                Consumer<UserProvider>(
                  builder: (context, userProvider, _) {
                    // Usando sellerId para comparação mais segura
                    final isMe = userProvider.user?.uid == widget.ad.sellerId;
                    
                    return GestureDetector(
                      onTap: () {
                        if (isMe) {
                          if (userProvider.user?.hasStore == true) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const MyStoreScreen()));
                          }
                        } else {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => SellerProfileScreen(
                                sellerId: widget.ad.sellerId,
                                sellerName: widget.ad.sellerName,
                              )
                            )
                          );
                        }
                      },
                      child: Container(
                        color: cardBg,
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppTheme.facebookBlue.withOpacity(0.12),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.facebookBlue.withOpacity(0.3),
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  widget.ad.sellerName[0].toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    color: AppTheme.facebookBlue,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
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
                                    isMe ? 'Você' : widget.ad.sellerName,
                                    style: GoogleFonts.outfit(
                                      color: textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    isMe ? 'Ver sua loja' : 'Ver perfil completo',
                                    style: GoogleFonts.outfit(
                                      color: AppTheme.facebookBlue,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                color: mutedColor, size: 24),
                          ],
                        ),
                      ),
                    );
                  }
                ).animate().fadeIn(delay: 240.ms),

                // Espaço para os botões fixos não cobrirem
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),

      // ── Botões fixos no fundo ──────────────────────────────────
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(top: BorderSide(color: border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Botão chat
            Expanded(
              child: Consumer<UserProvider>(
                builder: (context, userProvider, _) {
                  final user = userProvider.user;
                  final isMe = user?.uid == widget.ad.sellerId;

                  // Desabilita o botão se for o próprio anúncio
                  // ou se o sellerId estiver vazio (anúncio sem vendedor válido)
                  final canChat = !isMe && widget.ad.sellerId.isNotEmpty;

                  return GestureDetector(
                    onTap: canChat ? () async {
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Faça login para enviar mensagens!'),
                          ),
                        );
                        return;
                      }

                      // Mostra loading no botão durante a criação do chat
                      try {
                        final firestore = FirestoreService();
                        final chatId = await firestore.getOrCreateChat(
                          user.uid,
                          widget.ad.sellerId,
                          widget.ad.id,
                          adTitle: widget.ad.title,
                        );

                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                chatId: chatId,
                                otherUserName: widget.ad.sellerName,
                                adTitle: widget.ad.title,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceFirst('Exception: ', ''),
                              ),
                              backgroundColor: AppTheme.error,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        }
                      }
                    } : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: canChat ? AppTheme.facebookBlue : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Chat',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              ),
            ),

            const SizedBox(width: 10),

            // Botão ligar
            GestureDetector(
              onTap: () => _showContactOptions(context, widget.ad.sellerId),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Icon(
                  Icons.phone_rounded,
                  color: AppTheme.facebookBlue,
                  size: 24,
                ),
              ),
            ).animate().fadeIn(delay: 350.ms),
          ],
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required bool isDark,
    required Color border,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppTheme.facebookBlue.withOpacity(0.1)
            : (isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight
              ? AppTheme.facebookBlue.withOpacity(0.3)
              : border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlight
                ? AppTheme.facebookBlue
                : (isDark ? AppTheme.whiteSecondary : Colors.grey.shade600),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: highlight
                  ? AppTheme.facebookBlue
                  : (isDark ? AppTheme.whiteSecondary : Colors.grey.shade700),
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
class _FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenGallery({required this.images, required this.initialIndex});

  @override
  State<_FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<_FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Galeria
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: 'ad_img_${index == widget.initialIndex ? "main" : "gallery"}_$index',
                    child: Image.network(
                      widget.images[index],
                      fit: BoxFit.contain,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          // Botão Fechar
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
              ),
            ),
          ),

          // Indicador de página
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          // Setas de navegação (apenas se houver mais de uma imagem)
          if (widget.images.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            if (_currentIndex < widget.images.length - 1)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}