import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/ad_model.dart';
import '../theme/app_theme.dart';

enum MarketplaceSort { recommended, newest, priceLow, priceHigh }

enum PublicationDateFilter { any, last24h, last7days, last30days }

class MarketplaceFilters {
  final MarketplaceSort sort;
  final double? minPrice;
  final double? maxPrice;
  final String? adType;
  final String? propertyOfferType;
  final String? condition;
  final PublicationDateFilter publicationDate;
  final String? category;
  final int? minYear;
  final int? maxYear;
  final String? manufacturer;
  final String? fuelType;
  final int? maxKm;
  final String? transmission;
  final Set<String> vehicleFeatures;

  const MarketplaceFilters({
    this.sort = MarketplaceSort.recommended,
    this.minPrice,
    this.maxPrice,
    this.adType,
    this.propertyOfferType,
    this.condition,
    this.publicationDate = PublicationDateFilter.any,
    this.category,
    this.minYear,
    this.maxYear,
    this.manufacturer,
    this.fuelType,
    this.maxKm,
    this.transmission,
    this.vehicleFeatures = const {},
  });

  MarketplaceFilters copyWith({
    MarketplaceSort? sort,
    double? minPrice,
    double? maxPrice,
    String? adType,
    String? propertyOfferType,
    String? condition,
    PublicationDateFilter? publicationDate,
    String? category,
    int? minYear,
    int? maxYear,
    String? manufacturer,
    String? fuelType,
    int? maxKm,
    String? transmission,
    Set<String>? vehicleFeatures,
    bool resetMinPrice = false,
    bool resetMaxPrice = false,
    bool resetAdType = false,
    bool resetPropertyOfferType = false,
    bool resetCondition = false,
    bool resetCategory = false,
    bool resetMinYear = false,
    bool resetMaxYear = false,
    bool resetManufacturer = false,
    bool resetFuelType = false,
    bool resetMaxKm = false,
    bool resetTransmission = false,
  }) {
    return MarketplaceFilters(
      sort: sort ?? this.sort,
      minPrice: resetMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: resetMaxPrice ? null : (maxPrice ?? this.maxPrice),
      adType: resetAdType ? null : (adType ?? this.adType),
      propertyOfferType: resetPropertyOfferType
          ? null
          : (propertyOfferType ?? this.propertyOfferType),
      condition: resetCondition ? null : (condition ?? this.condition),
      publicationDate: publicationDate ?? this.publicationDate,
      category: resetCategory ? null : (category ?? this.category),
      minYear: resetMinYear ? null : (minYear ?? this.minYear),
      maxYear: resetMaxYear ? null : (maxYear ?? this.maxYear),
      manufacturer:
          resetManufacturer ? null : (manufacturer ?? this.manufacturer),
      fuelType: resetFuelType ? null : (fuelType ?? this.fuelType),
      maxKm: resetMaxKm ? null : (maxKm ?? this.maxKm),
      transmission:
          resetTransmission ? null : (transmission ?? this.transmission),
      vehicleFeatures: vehicleFeatures ?? this.vehicleFeatures,
    );
  }

  static const empty = MarketplaceFilters();
}

extension MarketplaceFiltersMatching on MarketplaceFilters {
  bool matchesAd(AdModel ad) {
    if (category != null && category!.isNotEmpty) {
      final resolvedCategory = AdModel.resolveCategoryValue(category!);
      if (ad.category != resolvedCategory) return false;
    }

    if (adType != null && adType!.isNotEmpty && ad.type != adType) {
      return false;
    }

    if (propertyOfferType != null &&
        propertyOfferType!.isNotEmpty &&
        ad.propertyOfferType != propertyOfferType) {
      return false;
    }

    if (minPrice != null && ad.price < minPrice!) {
      return false;
    }

    if (maxPrice != null && ad.price > maxPrice!) {
      return false;
    }

    final now = DateTime.now();
    if (publicationDate == PublicationDateFilter.last24h &&
        now.difference(ad.createdAt) > const Duration(hours: 24)) {
      return false;
    }
    if (publicationDate == PublicationDateFilter.last7days &&
        now.difference(ad.createdAt) > const Duration(days: 7)) {
      return false;
    }
    if (publicationDate == PublicationDateFilter.last30days &&
        now.difference(ad.createdAt) > const Duration(days: 30)) {
      return false;
    }

    if (minYear != null &&
        (ad.vehicleYear == null || ad.vehicleYear! < minYear!)) {
      return false;
    }

    if (maxYear != null &&
        (ad.vehicleYear == null || ad.vehicleYear! > maxYear!)) {
      return false;
    }

    if (manufacturer != null &&
        manufacturer!.trim().isNotEmpty &&
        AdModel.normalizeValue(ad.vehicleBrand ?? '') !=
            AdModel.normalizeValue(manufacturer!)) {
      return false;
    }

    if (fuelType != null &&
        fuelType!.trim().isNotEmpty &&
        AdModel.normalizeValue(ad.vehicleFuelType ?? '') !=
            AdModel.normalizeValue(fuelType!)) {
      return false;
    }

    if (maxKm != null && ad.km != null && ad.km! > maxKm!) {
      return false;
    }

    if (vehicleFeatures.isNotEmpty) {
      final adFeatures =
          ad.vehicleOptionals.map(AdModel.normalizeValue).toSet();
      final requiredFeatures = vehicleFeatures.map(AdModel.normalizeValue);
      if (!requiredFeatures.every(adFeatures.contains)) {
        return false;
      }
    }

    return true;
  }
}

class MarketplaceLocationActions extends StatelessWidget {
  final String locationLabel;
  final VoidCallback onLocationTap;
  final VoidCallback onFiltersTap;
  final VoidCallback onSavedTap;
  final bool compact;

  const MarketplaceLocationActions({
    super.key,
    required this.locationLabel,
    required this.onLocationTap,
    required this.onFiltersTap,
    required this.onSavedTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppTheme.black : Colors.white;
    final subtle = isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5);
    final textColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFDCE3EC);
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.1)
        : const Color(0xFF0F172A).withValues(alpha: 0.03);

    return Container(
      color: background,
      padding: EdgeInsets.fromLTRB(12, compact ? 8 : 10, 12, compact ? 8 : 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onLocationTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: subtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: shadowColor,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on_rounded,
                      color: AppTheme.facebookBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        locationLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.roboto(
                          color: textColor,
                          fontSize: compact ? 13.5 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.tune_rounded,
            label: 'Filtros',
            onTap: onFiltersTap,
            background: subtle,
            isDark: isDark,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            icon: Icons.bookmark_border_rounded,
            label: null,
            onTap: onSavedTap,
            background: subtle,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final Color background;
  final bool isDark;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.background,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFDCE3EC);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.1)
                  : const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isDark ? Colors.white : Colors.black87,
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: GoogleFonts.roboto(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
