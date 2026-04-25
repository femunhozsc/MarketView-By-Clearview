import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class MarketViewTopBar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onSearchTap;
  final VoidCallback onLogoTap;
  final VoidCallback onMenuTap;

  const MarketViewTopBar({
    super.key,
    required this.onSearchTap,
    required this.onLogoTap,
    required this.onMenuTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : Colors.white;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final iconColor = isDark ? Colors.white : Colors.black87;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : const Color(0xFF0F172A).withValues(alpha: 0.04);
    const marketColor = Color(0xFF0066EE);
    final viewColor = isDark ? Colors.white : const Color(0xFF303030);

    return Material(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: preferredSize.height,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: border)),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              MarketViewLogo(
                onTap: onLogoTap,
                marketColor: marketColor,
                viewColor: viewColor,
              ),
              const Spacer(),
              _CircleIconButton(
                icon: Icons.search_rounded,
                onTap: onSearchTap,
                background:
                    isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                color: iconColor,
              ),
              const SizedBox(width: 8),
              _CircleIconButton(
                icon: Icons.menu_rounded,
                onTap: onMenuTap,
                background:
                    isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MarketViewLogo extends StatelessWidget {
  final VoidCallback onTap;
  final Color marketColor;
  final Color? viewColor;
  final double fontSize;

  const MarketViewLogo({
    super.key,
    required this.onTap,
    this.marketColor = const Color(0xFF0066EE),
    this.viewColor,
    this.fontSize = 23,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedViewColor =
        viewColor ?? (isDark ? Colors.white : const Color(0xFF303030));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Market',
                style: GoogleFonts.montserrat(
                  color: marketColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.9,
                ),
              ),
              TextSpan(
                text: 'View',
                style: GoogleFonts.montserrat(
                  color: resolvedViewColor,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color color;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFD7DEE8),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.14)
                  : const Color(0xFF0F172A).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}
