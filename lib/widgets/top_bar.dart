import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class MarketViewTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;
  final VoidCallback onNotificationTap;
  final VoidCallback onLogoTap;

  const MarketViewTopBar({
    super.key,
    required this.onMenuTap,
    required this.onSearchTap,
    required this.onNotificationTap,
    required this.onLogoTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE8E8E8);
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Container(
      height: preferredSize.height,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo clicável
              GestureDetector(
                onTap: onLogoTap,
                child: _buildLogo(isDark)
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.15, end: 0),
              ),

              const Spacer(),

              // Ícones sem fundo
              Row(
                children: [
                  _iconBtn(
                    icon: Icons.search_rounded,
                    onTap: onSearchTap,
                    color: iconColor,
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(width: 4),

                  _notifBtn(color: iconColor)
                      .animate()
                      .fadeIn(delay: 180.ms),

                  const SizedBox(width: 4),

                  _menuBtn(color: iconColor)
                      .animate()
                      .fadeIn(delay: 260.ms),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Row(
      children: [
        // Logo sem fundo azul — apenas imagem ou ícone simples
        Image.asset(
          'assets/images/logo_a.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.storefront_rounded,
            color: AppTheme.facebookBlue,
            size: 34,
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Market',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: 'View',
                style: GoogleFonts.outfit(
                  color: AppTheme.facebookBlue,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ícone SEM fundo
  Widget _iconBtn({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, color: color, size: 26),
      ),
    );
  }

  Widget _notifBtn({required Color color}) {
    return InkWell(
      onTap: onNotificationTap,
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.notifications_outlined, color: color, size: 26),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuBtn({required Color color}) {
    return InkWell(
      onTap: onMenuTap,
      borderRadius: BorderRadius.circular(25),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _line(22, color),
            const SizedBox(height: 5),
            _line(16, color),
            const SizedBox(height: 5),
            _line(11, color),
          ],
        ),
      ),
    );
  }

  Widget _line(double w, Color color) {
    return Container(
      width: w,
      height: 2.2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}