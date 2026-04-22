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
  final String? categoryType;
  final String? servicePriceType;
  final String? propertyOfferType;
  final String? propertyFurnishing;
  final String? condition;
  final PublicationDateFilter publicationDate;
  final String? category;
  final double? minArea;
  final double? maxArea;
  final int? minBedrooms;
  final int? minBathrooms;
  final int? minParkingSpots;
  final int? minYear;
  final int? maxYear;
  final String? manufacturer;
  final String? fuelType;
  final String? vehicleColor;
  final int? maxKm;
  final String? transmission;
  final Set<String> vehicleFeatures;
  final Map<String, String> customAttributeFilters;

  const MarketplaceFilters({
    this.sort = MarketplaceSort.recommended,
    this.minPrice,
    this.maxPrice,
    this.adType,
    this.categoryType,
    this.servicePriceType,
    this.propertyOfferType,
    this.propertyFurnishing,
    this.condition,
    this.publicationDate = PublicationDateFilter.any,
    this.category,
    this.minArea,
    this.maxArea,
    this.minBedrooms,
    this.minBathrooms,
    this.minParkingSpots,
    this.minYear,
    this.maxYear,
    this.manufacturer,
    this.fuelType,
    this.vehicleColor,
    this.maxKm,
    this.transmission,
    this.vehicleFeatures = const {},
    this.customAttributeFilters = const {},
  });

  MarketplaceFilters copyWith({
    MarketplaceSort? sort,
    double? minPrice,
    double? maxPrice,
    String? adType,
    String? categoryType,
    String? servicePriceType,
    String? propertyOfferType,
    String? propertyFurnishing,
    String? condition,
    PublicationDateFilter? publicationDate,
    String? category,
    double? minArea,
    double? maxArea,
    int? minBedrooms,
    int? minBathrooms,
    int? minParkingSpots,
    int? minYear,
    int? maxYear,
    String? manufacturer,
    String? fuelType,
    String? vehicleColor,
    int? maxKm,
    String? transmission,
    Set<String>? vehicleFeatures,
    Map<String, String>? customAttributeFilters,
    bool resetMinPrice = false,
    bool resetMaxPrice = false,
    bool resetAdType = false,
    bool resetCategoryType = false,
    bool resetServicePriceType = false,
    bool resetPropertyOfferType = false,
    bool resetPropertyFurnishing = false,
    bool resetCondition = false,
    bool resetCategory = false,
    bool resetMinArea = false,
    bool resetMaxArea = false,
    bool resetMinBedrooms = false,
    bool resetMinBathrooms = false,
    bool resetMinParkingSpots = false,
    bool resetMinYear = false,
    bool resetMaxYear = false,
    bool resetManufacturer = false,
    bool resetFuelType = false,
    bool resetVehicleColor = false,
    bool resetMaxKm = false,
    bool resetTransmission = false,
    bool resetCustomAttributeFilters = false,
  }) {
    return MarketplaceFilters(
      sort: sort ?? this.sort,
      minPrice: resetMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: resetMaxPrice ? null : (maxPrice ?? this.maxPrice),
      adType: resetAdType ? null : (adType ?? this.adType),
      categoryType:
          resetCategoryType ? null : (categoryType ?? this.categoryType),
      servicePriceType: resetServicePriceType
          ? null
          : (servicePriceType ?? this.servicePriceType),
      propertyOfferType: resetPropertyOfferType
          ? null
          : (propertyOfferType ?? this.propertyOfferType),
      propertyFurnishing: resetPropertyFurnishing
          ? null
          : (propertyFurnishing ?? this.propertyFurnishing),
      condition: resetCondition ? null : (condition ?? this.condition),
      publicationDate: publicationDate ?? this.publicationDate,
      category: resetCategory ? null : (category ?? this.category),
      minArea: resetMinArea ? null : (minArea ?? this.minArea),
      maxArea: resetMaxArea ? null : (maxArea ?? this.maxArea),
      minBedrooms: resetMinBedrooms ? null : (minBedrooms ?? this.minBedrooms),
      minBathrooms:
          resetMinBathrooms ? null : (minBathrooms ?? this.minBathrooms),
      minParkingSpots: resetMinParkingSpots
          ? null
          : (minParkingSpots ?? this.minParkingSpots),
      minYear: resetMinYear ? null : (minYear ?? this.minYear),
      maxYear: resetMaxYear ? null : (maxYear ?? this.maxYear),
      manufacturer:
          resetManufacturer ? null : (manufacturer ?? this.manufacturer),
      fuelType: resetFuelType ? null : (fuelType ?? this.fuelType),
      vehicleColor:
          resetVehicleColor ? null : (vehicleColor ?? this.vehicleColor),
      maxKm: resetMaxKm ? null : (maxKm ?? this.maxKm),
      transmission:
          resetTransmission ? null : (transmission ?? this.transmission),
      vehicleFeatures: vehicleFeatures ?? this.vehicleFeatures,
      customAttributeFilters: resetCustomAttributeFilters
          ? const {}
          : (customAttributeFilters ?? this.customAttributeFilters),
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

    if (categoryType != null && categoryType!.trim().isNotEmpty) {
      final normalizedFilter = AdModel.normalizeValue(categoryType!);
      final normalizedAdCategoryType = AdModel.normalizeValue(
        ad.categoryType?.trim() ?? '',
      );
      final normalizedAdDisplayCategoryType = AdModel.normalizeValue(
        ad.displayCategoryTypeLabel,
      );
      if (normalizedAdCategoryType != normalizedFilter &&
          normalizedAdDisplayCategoryType != normalizedFilter) {
        return false;
      }
    }

    if (servicePriceType != null &&
        servicePriceType!.isNotEmpty &&
        ad.servicePriceType != servicePriceType) {
      return false;
    }

    if (propertyOfferType != null &&
        propertyOfferType!.isNotEmpty &&
        ad.propertyOfferType != propertyOfferType) {
      return false;
    }

    if (propertyFurnishing != null &&
        propertyFurnishing!.isNotEmpty &&
        ad.propertyFurnishing != propertyFurnishing) {
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

    if (minArea != null &&
        (ad.propertyArea == null || ad.propertyArea! < minArea!)) {
      return false;
    }

    if (maxArea != null &&
        (ad.propertyArea == null || ad.propertyArea! > maxArea!)) {
      return false;
    }

    if (minBedrooms != null &&
        (ad.propertyBedrooms == null || ad.propertyBedrooms! < minBedrooms!)) {
      return false;
    }

    if (minBathrooms != null &&
        (ad.propertyBathrooms == null ||
            ad.propertyBathrooms! < minBathrooms!)) {
      return false;
    }

    if (minParkingSpots != null &&
        (ad.propertyParkingSpots == null ||
            ad.propertyParkingSpots! < minParkingSpots!)) {
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

    if (vehicleColor != null &&
        vehicleColor!.trim().isNotEmpty &&
        AdModel.normalizeValue(ad.vehicleColor ?? '') !=
            AdModel.normalizeValue(vehicleColor!)) {
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

    if (customAttributeFilters.isNotEmpty) {
      final adAttributes = <String, String>{};
      for (final attribute in ad.customAttributes) {
        final key = AdModel.normalizeValue(attribute.key);
        final value = AdModel.normalizeValue(attribute.value);
        if (key.isNotEmpty && value.isNotEmpty) {
          adAttributes[key] = value;
        }
      }

      for (final entry in customAttributeFilters.entries) {
        final filterKey = AdModel.normalizeValue(entry.key);
        final filterValue = AdModel.normalizeValue(entry.value);
        if (filterKey.isEmpty || filterValue.isEmpty) continue;
        if (adAttributes[filterKey] != filterValue) {
          return false;
        }
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
