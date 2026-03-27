import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/ad_model.dart';
import '../theme/app_theme.dart';
import 'favorite_button.dart';

class AdCard extends StatefulWidget {
  final AdModel ad;
  final int index;
  final VoidCallback? onTap;

  const AdCard({
    super.key,
    required this.ad,
    required this.index,
    this.onTap,
  });

  @override
  State<AdCard> createState() => _AdCardState();
}

class _AdCardState extends State<AdCard> {
  bool _isPressed = false;

  // ✅ Formato R$4.500,00
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

  // ✅ Km formatado: 34.500 km
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

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    return '${diff.inDays}d';
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'servico':
        return const Color(0xFF9B59B6);
      default:
        return AppTheme.facebookBlue;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'servico':
        return 'Serviço';
      default:
        return 'Produto';
    }
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? AppTheme.whiteMuted : Colors.grey.shade500;
    final imgBg = isDark ? AppTheme.blackLight : const Color(0xFFF5F5F5);
    final typeColor = _getTypeColor(widget.ad.type);
    final isVehicle = widget.ad.category == 'Veículos';

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Imagem ──────────────────────────────────────────
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: Container(
                    width: double.infinity,
                    color: imgBg,
                    child: Stack(
                      children: [
                        if (widget.ad.images.isNotEmpty)
                        Image.network(
                          widget.ad.images.first,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              _getCategoryIcon(widget.ad.category),
                              color: isDark ? Colors.white12 : Colors.grey.shade300,
                              size: 52,
                            ),
                          ),
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                                color: AppTheme.facebookBlue.withOpacity(0.3),
                              ),
                            );
                          },
                        )
                      else
                        Center(
                          child: Icon(
                            _getCategoryIcon(widget.ad.category),
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                            size: 52,
                          ),
                        ),
                      // Badge favorito
                      Positioned(
                        top: 8,
                        right: 8,
                        child: FavoriteButton(adId: widget.ad.id, size: 30),
                      ),
                      // Badge tipo
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getTypeLabel(widget.ad.type),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ),

              // ── Conteúdo ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Título
                    Row(
                      children: [
                        if (widget.ad.storeId != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.store_rounded, size: 14, color: AppTheme.facebookBlue),
                          ),
                        Expanded(
                          child: Text(
                            widget.ad.title,
                            style: GoogleFonts.outfit(
                              color: titleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    // Preço — formato R$4.500,00
                    Text(
                      _formatPrice(widget.ad.price),
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : const Color(0xFF4A4A4A),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Localização
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            color: mutedColor, size: 12),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            widget.ad.location,
                            style: GoogleFonts.outfit(
                              color: mutedColor,
                              fontSize: 11,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        Text(
                          _formatTime(widget.ad.createdAt),
                          style: GoogleFonts.outfit(
                            color: mutedColor,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),

                    // ✅ Km do veículo (só para Veículos)
                    if (isVehicle && widget.ad.km != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.speed_rounded,
                              color: mutedColor, size: 12),
                          const SizedBox(width: 3),
                          Text(
                            _formatKm(widget.ad.km!),
                            style: GoogleFonts.outfit(
                              color: mutedColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 8),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 8),
                    
                    // ── Perfil / Loja do Anunciante ──────────────────
                    Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.facebookBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                            image: (widget.ad.storeId != null && widget.ad.storeLogo != null && widget.ad.storeLogo!.isNotEmpty)
                                ? DecorationImage(image: NetworkImage(widget.ad.storeLogo!), fit: BoxFit.cover)
                                : (widget.ad.sellerAvatar.isNotEmpty && widget.ad.sellerAvatar.startsWith('http'))
                                    ? DecorationImage(image: NetworkImage(widget.ad.sellerAvatar), fit: BoxFit.cover)
                                    : null,
                          ),
                          child: ((widget.ad.storeId != null && widget.ad.storeLogo != null && widget.ad.storeLogo!.isNotEmpty) ||
                                 (widget.ad.sellerAvatar.isNotEmpty && widget.ad.sellerAvatar.startsWith('http')))
                              ? null
                              : Center(
                                  child: Text(
                                    widget.ad.storeId != null
                                        ? (widget.ad.storeName?.isNotEmpty == true ? widget.ad.storeName![0].toUpperCase() : 'L')
                                        : (widget.ad.sellerName.isNotEmpty ? widget.ad.sellerName[0].toUpperCase() : 'U'),
                                    style: const TextStyle(color: AppTheme.facebookBlue, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.ad.storeId != null ? (widget.ad.storeName ?? 'Loja parceira') : widget.ad.sellerName,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.whiteMuted : Colors.grey.shade600,
                            ),
                            maxLines: 1,
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
        )
            .animate(delay: Duration(milliseconds: widget.index * 80))
            .fadeIn(duration: 400.ms)
            .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}