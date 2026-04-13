import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ad_model.dart';
import '../models/store_model.dart';
import '../theme/app_theme.dart';
import 'store_favorite_button.dart';

class StoreListCard extends StatelessWidget {
  const StoreListCard({
    super.key,
    required this.store,
    required this.onTap,
    this.showFavoriteButton = true,
    this.showDivider = true,
  });

  final StoreModel store;
  final VoidCallback onTap;
  final bool showFavoriteButton;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF202124);
    final subtitleColor =
        isDark ? AppTheme.whiteSecondary : const Color(0xFF6B7280);
    final dividerColor =
        isDark ? AppTheme.blackBorder : const Color(0xFFE9EEF5);
    final imageUrl =
        (store.logo?.trim().isNotEmpty ?? false) ? store.logo! : store.banner;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _fallbackThumb(isDark),
                          )
                        : _fallbackThumb(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 72,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                store.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 13.8,
                                  height: 1.08,
                                  fontWeight: FontWeight.w700,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildRating(subtitleColor),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AdModel.displayLabel(store.category),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.manrope(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.facebookBlue,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (store.hasDelivery)
                              const _StoreChip(
                                label: 'Entrega',
                                backgroundColor: Color(0xFFE6F4EA),
                                textColor: Color(0xFF188038),
                              ),
                            if (store.hasDelivery && store.hasInstallments)
                              const SizedBox(width: 6),
                            if (store.hasInstallments)
                              const _StoreChip(
                                label: 'Parcelamento',
                                backgroundColor: Color(0xFFF1F3F4),
                                textColor: Color(0xFF5F6368),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (showFavoriteButton) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: StoreFavoriteButton(
                      storeId: store.id,
                      size: 30,
                      backgroundColor:
                          isDark ? AppTheme.blackCard : const Color(0xFFF6F8FB),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
          ),
      ],
    );
  }

  Widget _buildRating(Color subtitleColor) {
    final hasReviews = store.totalReviews > 0 && store.rating > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.star_rounded,
          size: 14,
          color: Color(0xFFF4B400),
        ),
        const SizedBox(width: 2),
        Text(
          hasReviews ? store.rating.toStringAsFixed(1) : '--',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: subtitleColor,
          ),
        ),
      ],
    );
  }

  Widget _fallbackThumb(bool isDark) {
    return Container(
      color: isDark ? AppTheme.blackLight : const Color(0xFFF3F6FA),
      child: const Icon(
        Icons.storefront_rounded,
        color: AppTheme.facebookBlue,
        size: 28,
      ),
    );
  }
}

class _StoreChip extends StatelessWidget {
  const _StoreChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10.4,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}
