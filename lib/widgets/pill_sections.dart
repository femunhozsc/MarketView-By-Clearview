import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class PillSections extends StatefulWidget {
  final Function(int) onSectionChanged;

  const PillSections({super.key, required this.onSectionChanged});

  @override
  State<PillSections> createState() => _PillSectionsState();
}

class _PillSectionsState extends State<PillSections> {
  int _selectedIndex = 0;

  final List<_SectionItem> _sections = [
    _SectionItem(label: 'Para Você', icon: Icons.auto_awesome_rounded),
    _SectionItem(label: 'Produtos', icon: Icons.inventory_2_outlined),
    _SectionItem(label: 'Serviços', icon: Icons.handyman_outlined),
    _SectionItem(label: 'Lojas', icon: Icons.store_outlined),
    _SectionItem(label: 'Categorias', icon: Icons.grid_view_rounded),
    _SectionItem(label: 'Favoritos', icon: Icons.favorite_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 58,
      color: isDark ? AppTheme.black : Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _sections.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PillItem(
              section: _sections[index],
              isSelected: isSelected,
              delay: index * 70,
              isDark: isDark,
              onTap: () {
                setState(() => _selectedIndex = index);
                widget.onSectionChanged(index);
              },
            ),
          );
        },
      ),
    );
  }
}

class _PillItem extends StatefulWidget {
  final _SectionItem section;
  final bool isSelected;
  final int delay;
  final bool isDark;
  final VoidCallback onTap;

  const _PillItem({
    required this.section,
    required this.isSelected,
    required this.delay,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_PillItem> createState() => _PillItemState();
}

class _PillItemState extends State<_PillItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 130), vsync: this);
    _scale = Tween<double>(begin: 1.0, end: 0.94)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selBg = AppTheme.facebookBlue;
    final unselBg =
        widget.isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5);
    final selBorder = AppTheme.facebookBlue;
    final unselBorder = widget.isDark
        ? AppTheme.blackBorder
        : const Color(0xFFDDDDDD);
    final selIcon = Colors.white;
    final unselIcon =
        widget.isDark ? AppTheme.whiteSecondary : Colors.grey.shade600;

    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected ? selBg : unselBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected ? selBorder : unselBorder,
              width: 1,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.facebookBlue.withOpacity(0.25),
                      blurRadius: 8,
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.section.icon,
                size: 15,
                color: widget.isSelected ? selIcon : unselIcon,
              ),
              const SizedBox(width: 5),
              Text(
                widget.section.label,
                style: GoogleFonts.outfit(
                  color: widget.isSelected ? selIcon : unselIcon,
                  fontSize: 13,
                  fontWeight: widget.isSelected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        )
            .animate(delay: Duration(milliseconds: widget.delay))
            .fadeIn(duration: 350.ms)
            .slideX(begin: 0.25, end: 0),
      ),
    );
  }
}

class _SectionItem {
  final String label;
  final IconData icon;
  _SectionItem({required this.label, required this.icon});
}
