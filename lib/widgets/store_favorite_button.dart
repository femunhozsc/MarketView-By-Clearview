import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/user_provider.dart';

class StoreFavoriteButton extends StatelessWidget {
  const StoreFavoriteButton({
    super.key,
    required this.storeId,
    this.size = 36,
    this.backgroundColor,
  });

  final String storeId;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final isFavorite = userProvider.isFavoriteStore(storeId);
    final bg = backgroundColor ?? Colors.white;

    return GestureDetector(
      onTap: () => context.read<UserProvider>().toggleFavoriteStore(storeId),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isFavorite ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
          color: isFavorite ? const Color(0xFFE53935) : const Color(0xFF7B8694),
          size: size * 0.5,
        ),
      ),
    );
  }
}
