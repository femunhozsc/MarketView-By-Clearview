import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

import '../theme/app_theme.dart';

class PillSections extends StatefulWidget {
  final Function(int) onSectionChanged;
  final int selectedIndex;

  const PillSections({
    super.key,
    required this.onSectionChanged,
    required this.selectedIndex,
  });

  @override
  State<PillSections> createState() => _PillSectionsState();
}

class _PillSectionsState extends State<PillSections> {
  final _scrollController = ScrollController();
  late final List<GlobalKey> _itemKeys;

  List<String> _getSections(bool isNewUser) {
    return [
      isNewUser ? 'Recomendados' : 'Para voc\u00EA',
      'Produtos',
      'Servi\u00E7os',
      'Lojas',
      'Compro',
      'Categorias',
      'Favoritos',
    ];
  }

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(7, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureSelectedVisible(animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant PillSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ensureSelectedVisible();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureSelectedVisible({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final currentContext = _itemKeys[widget.selectedIndex].currentContext;
    if (currentContext == null) return;

    Scrollable.ensureVisible(
      currentContext,
      alignment: 0.5,
      duration: animated ? const Duration(milliseconds: 260) : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shellColor = isDark ? AppTheme.black : Colors.white;
    final shellBorder = isDark ? AppTheme.blackBorder : const Color(0xFFE3E8EF);
    final selectedBg = isDark ? Colors.white : const Color(0xFF0F172A);
    final selectedText = isDark ? Colors.black87 : Colors.white;
    final idleBg = isDark ? const Color(0xFF171B22) : const Color(0xFFF4F7FB);
    final idleText = isDark ? AppTheme.whiteSecondary : const Color(0xFF526071);

    final user = context.watch<UserProvider>().user;
    final isNewUser = user == null || user.categoryClicks.isEmpty;
    final currentSections = _getSections(isNewUser);

    return Container(
      height: 68,
      color: shellColor,
      child: ListView.separated(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        scrollDirection: Axis.horizontal,
        itemCount: currentSections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == widget.selectedIndex;
          return InkWell(
            key: _itemKeys[index],
            onTap: () => widget.onSectionChanged(index),
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? selectedBg : idleBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.3)
                          : shellBorder)
                      : shellBorder,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.16)
                              : const Color(0xFF0F172A).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  currentSections[index],
                  style: GoogleFonts.manrope(
                    color: selected ? selectedText : idleText,
                    fontSize: 13.5,
                    height: 1,
                    letterSpacing: -0.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
