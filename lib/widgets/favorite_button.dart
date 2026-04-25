import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

import '../screens/profile_screen.dart';

/// Botão de favorito reutilizável que consome diretamente o UserProvider
/// para determinar seu estado, garantindo consistência em todas as telas.
class FavoriteButton extends StatefulWidget {
  final String adId;
  final double size;
  final bool showBackground;

  const FavoriteButton({
    super.key,
    required this.adId,
    this.size = 30,
    this.showBackground = true,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton>
    with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  bool _isFavorite(UserProvider userProvider) {
    return userProvider.user?.favoriteAdIds.contains(widget.adId) ?? false;
  }

  Future<void> _toggle() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (_isLoading) return;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ProfileScreen()),
      );
      return;
    }

    setState(() => _isLoading = true);
    _animCtrl.forward(from: 0);

    final isFav = _isFavorite(userProvider);
    try {
      await _firestore.toggleFavorite(user.uid, widget.adId, add: !isFav);
      // Atualiza o estado local do provider
      final updatedFavs = List<String>.from(user.favoriteAdIds);
      if (isFav) {
        updatedFavs.remove(widget.adId);
      } else {
        updatedFavs.add(widget.adId);
      }
      userProvider.setUser(user.copyWith(favoriteAdIds: updatedFavs));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao atualizar favorito')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isFav = _isFavorite(userProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconSize = widget.size * 0.53;
    final backgroundColor =
        isDark ? AppTheme.blackLight : Colors.white.withValues(alpha: 0.97);
    final inactiveIconColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : Colors.grey.shade500;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFD7DEE8);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.18)
        : const Color(0xFF0F172A).withValues(alpha: 0.08);
    final icon =
        isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded;
    final iconColor = isFav ? Colors.red.shade500 : inactiveIconColor;

    return InkWell(
      onTap: _isLoading ? null : _toggle,
      borderRadius: BorderRadius.circular(999),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: widget.showBackground
            ? Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: iconSize,
                ),
              )
            : Icon(
                icon,
                color: iconColor,
                size: iconSize,
              ),
      ),
    );
  }
}
