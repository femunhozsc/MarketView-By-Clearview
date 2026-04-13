import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ad_model.dart';
import '../theme/app_theme.dart';
import 'favorite_button.dart';

class AdCard extends StatelessWidget {
  const AdCard({
    super.key,
    required this.ad,
    required this.index,
    this.onTap,
    this.badgeLabel,
    this.distanceKm,
  });

  final AdModel ad;
  final int index;
  final VoidCallback? onTap;
  final String? badgeLabel;
  final int? distanceKm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : Colors.black;
    final imageBg = isDark ? AppTheme.blackLight : const Color(0xFFF2F2F2);
    final labels = <({String text, Color bg, Color fg})>[
      if (ad.isWantedAd)
        (
          text: 'Compro',
          bg: isDark ? AppTheme.facebookBlue : const Color(0xFF0F5BD3),
          fg: Colors.white,
        ),
      if (badgeLabel != null && badgeLabel!.isNotEmpty)
        (
          text: badgeLabel!,
          bg: Colors.white,
          fg: Colors.black87,
        ),
    ];

    return Material(
      color: isDark ? AppTheme.blackCard : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1.06,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (ad.images.isNotEmpty)
                      Image.network(
                        ad.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: imageBg,
                          child: Icon(
                            Icons.sell_rounded,
                            color: Colors.grey.shade400,
                            size: 38,
                          ),
                        ),
                      )
                    else
                      ColoredBox(
                        color: imageBg,
                        child: Icon(
                          Icons.sell_rounded,
                          color: Colors.grey.shade400,
                          size: 38,
                        ),
                      ),
                    if (labels.isNotEmpty)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: labels
                              .map(
                                (label) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: label.bg.withValues(alpha: 0.94),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      label.text,
                                      style: GoogleFonts.roboto(
                                        color: label.fg,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: FavoriteButton(
                        adId: ad.id,
                        size: 30,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        ad.displayPriceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: titleColor,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ad.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: titleColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
