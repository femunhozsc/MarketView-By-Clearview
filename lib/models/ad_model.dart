import 'package:cloud_firestore/cloud_firestore.dart';

class AdModel {
  static const String productType = 'produto';
  static const String serviceType = 'servico';
  static const String intentSell = 'vendo';
  static const String intentBuy = 'compro';

  static const String servicePriceFixed = 'fixed';
  static const String servicePriceHourly = 'hourly';
  static const String servicePriceFixedPlusHourly = 'fixed_plus_hourly';
  static const String servicePriceDaily = 'daily';

  static const String propertyOfferSale = 'venda';
  static const String propertyOfferRent = 'aluguel';

  static const String propertyExtraNone = 'none';
  static const String propertyExtraCondo = 'condo';
  static const String propertyExtraCosts = 'costs';
  static const String propertyExtraCondoAndCosts = 'condo_and_costs';

  static const String propertyFurnishingUnfurnished = 'nao_mobiliado';
  static const String propertyFurnishingSemi = 'semi_mobiliado';
  static const String propertyFurnishingFurnished = 'mobiliado';

  final String id;
  final String sellerId;
  final String title;
  final String description;
  final double price;
  final String category;
  final String type;
  final String intent;
  final List<String> images;
  final List<String> imagePublicIds;
  final String location;
  final String sellerName;
  final String sellerAvatar;
  final DateTime createdAt;
  final int? km;
  final String? storeId;
  final String? storeName;
  final String? storeLogo;
  final String? sellerUserName;
  final String? sellerUserAvatar;
  final double? oldPrice;
  final int clickCount;
  final double? lat;
  final double? lng;
  final String servicePriceType;
  final double? hourlyPrice;
  final bool isActive;
  final String? categoryType;
  final String? categoryTypeCustomLabel;
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? vehicleYear;
  final List<String> vehicleOptionals;
  final String? vehicleColor;
  final String? vehicleFuelType;
  final int? vehicleOwnerCount;
  final String? propertyOfferType;
  final double? condoFee;
  final bool condoFeeOnRequest;
  final List<PropertyExtraCost> propertyMonthlyCosts;
  final double? propertyArea;
  final int? propertyBedrooms;
  final int? propertyBathrooms;
  final int? propertyParkingSpots;
  final String? propertyFurnishing;
  final List<AdAttribute> customAttributes;

  AdModel({
    required this.id,
    this.sellerId = '',
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.type,
    this.intent = intentSell,
    required this.images,
    this.imagePublicIds = const [],
    required this.location,
    required this.sellerName,
    this.sellerAvatar = '',
    required this.createdAt,
    this.km,
    this.storeId,
    this.storeName,
    this.storeLogo,
    this.sellerUserName,
    this.sellerUserAvatar,
    this.oldPrice,
    this.clickCount = 0,
    this.lat,
    this.lng,
    this.servicePriceType = servicePriceFixed,
    this.hourlyPrice,
    this.isActive = true,
    this.categoryType,
    this.categoryTypeCustomLabel,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleOptionals = const [],
    this.vehicleColor,
    this.vehicleFuelType,
    this.vehicleOwnerCount,
    this.propertyOfferType,
    this.condoFee,
    this.condoFeeOnRequest = false,
    this.propertyMonthlyCosts = const [],
    this.propertyArea,
    this.propertyBedrooms,
    this.propertyBathrooms,
    this.propertyParkingSpots,
    this.propertyFurnishing,
    this.customAttributes = const [],
  });

  bool get isStoreAd => storeId != null && storeId!.isNotEmpty;
  bool get isWantedAd => intent == intentBuy;
  bool get isForSaleAd => !isWantedAd;
  bool get isServiceAd => type == serviceType;
  bool get isSold => !isActive;
  bool get isVehicleCategory => normalizeValue(category) == 'veiculos';
  bool get isPropertyCategory => normalizeValue(category) == 'imoveis';
  bool get isVehicleProduct =>
      isForSaleAd && type == productType && isVehicleCategory;
  bool get isPropertyProduct =>
      isForSaleAd && type == productType && isPropertyCategory;
  bool get hasVehicleDetails =>
      isVehicleProduct &&
      ((vehicleBrand?.trim().isNotEmpty ?? false) ||
          (vehicleModel?.trim().isNotEmpty ?? false) ||
          vehicleYear != null ||
          km != null ||
          (vehicleOptionals.isNotEmpty) ||
          (vehicleColor?.trim().isNotEmpty ?? false) ||
          (vehicleFuelType?.trim().isNotEmpty ?? false) ||
          vehicleOwnerCount != null);
  bool get isPropertyRent =>
      isPropertyProduct && propertyOfferType == propertyOfferRent;
  bool get hasPropertyDetails =>
      isPropertyProduct &&
      ((categoryType?.trim().isNotEmpty ?? false) ||
          (propertyOfferType?.trim().isNotEmpty ?? false) ||
          propertyArea != null ||
          propertyBedrooms != null ||
          propertyBathrooms != null ||
          propertyParkingSpots != null ||
          (propertyFurnishing?.trim().isNotEmpty ?? false) ||
          condoFee != null ||
          condoFeeOnRequest ||
          propertyMonthlyCosts.isNotEmpty);
  bool get hasCustomAttributes => customAttributes.isNotEmpty;

  String get displayTypeLabel => type == serviceType ? 'Serviço' : 'Produto';
  String get displayIntentLabel => isWantedAd ? 'Compro' : 'Vendo';
  String get displayCategoryLabel => displayLabel(category);
  String get displayCategoryTypeLabel {
    final customLabel = categoryTypeCustomLabel?.trim() ?? '';
    if (customLabel.isNotEmpty) return customLabel;
    return displayLabel(categoryType?.trim() ?? '');
  }

  String get displayPropertyOfferLabel =>
      propertyOfferType == propertyOfferRent ? 'Aluguel' : 'Venda';
  String get displayPropertyFurnishingLabel {
    switch (propertyFurnishing) {
      case propertyFurnishingFurnished:
        return 'Mobiliado';
      case propertyFurnishingSemi:
        return 'Semi mobiliado';
      case propertyFurnishingUnfurnished:
        return 'Não mobiliado';
      default:
        return '';
    }
  }

  String get displaySellerName =>
      isStoreAd ? (storeName ?? sellerName) : formatShortPersonName(sellerName);

  String get displaySellerUserName =>
      formatShortPersonName(sellerUserName ?? '');

  String get displaySellerAvatar =>
      isStoreAd ? (storeLogo ?? sellerAvatar) : sellerAvatar;

  String get displayPriceLabel {
    if (isWantedAd) {
      return formatCurrency(price);
    }

    if (isPropertyRent) {
      return '${formatCurrency(price)}/mês';
    }

    if (!isServiceAd) {
      return formatCurrency(price);
    }

    switch (servicePriceType) {
      case servicePriceHourly:
        return '${formatCurrency(price)}/h';
      case servicePriceFixedPlusHourly:
        final hourly = hourlyPrice ?? 0;
        return '${formatCurrency(price)} + ${formatCurrency(hourly)}/h';
      case servicePriceDaily:
        return '${formatCurrency(price)}/dia';
      case servicePriceFixed:
      default:
        return formatCurrency(price);
    }
  }

  String get displayServicePriceTypeLabel {
    switch (servicePriceType) {
      case servicePriceHourly:
        return 'Cobrado por hora';
      case servicePriceFixedPlusHourly:
        return 'Valor fixo + hora';
      case servicePriceDaily:
        return 'Valor por diária';
      case servicePriceFixed:
      default:
        return 'Valor fixo';
    }
  }

  List<MapEntry<String, String>> get vehicleDetailEntries {
    final entries = <MapEntry<String, String>>[];

    if (km != null) {
      entries.add(MapEntry('Quilometragem', '${km!} km'));
    }
    if (vehicleBrand != null && vehicleBrand!.trim().isNotEmpty) {
      entries.add(MapEntry('Marca', vehicleBrand!.trim()));
    }
    if (vehicleModel != null && vehicleModel!.trim().isNotEmpty) {
      entries.add(MapEntry('Modelo', vehicleModel!.trim()));
    }
    if (vehicleYear != null) {
      entries.add(MapEntry('Ano', vehicleYear.toString()));
    }
    if (vehicleColor != null && vehicleColor!.trim().isNotEmpty) {
      entries.add(MapEntry('Cor', vehicleColor!.trim()));
    }
    if (vehicleFuelType != null && vehicleFuelType!.trim().isNotEmpty) {
      entries.add(
        MapEntry('Combustível', displayLabel(vehicleFuelType!.trim())),
      );
    }
    if (vehicleOwnerCount != null) {
      entries.add(
        MapEntry(
          'Proprietários',
          vehicleOwnerCount == 1
              ? '1 proprietário'
              : '$vehicleOwnerCount proprietários',
        ),
      );
    }
    if (vehicleOptionals.isNotEmpty) {
      entries.add(
        MapEntry('Opcionais', vehicleOptionals.map(displayLabel).join(', ')),
      );
    }

    return entries;
  }

  List<MapEntry<String, String>> get propertyDetailEntries {
    final entries = <MapEntry<String, String>>[];

    if (displayCategoryTypeLabel.isNotEmpty) {
      entries.add(MapEntry('Subtipo', displayCategoryTypeLabel));
    }
    if (propertyOfferType != null && propertyOfferType!.trim().isNotEmpty) {
      entries.add(MapEntry('Negócio', displayPropertyOfferLabel));
    }
    if (propertyArea != null) {
      entries.add(MapEntry('Área', _formatArea(propertyArea!)));
    }
    if (propertyBedrooms != null) {
      entries.add(MapEntry('Quartos', propertyBedrooms.toString()));
    }
    if (propertyBathrooms != null) {
      entries.add(MapEntry('Banheiros', propertyBathrooms.toString()));
    }
    if (propertyParkingSpots != null) {
      entries.add(MapEntry('Vagas', propertyParkingSpots.toString()));
    }
    if (displayPropertyFurnishingLabel.isNotEmpty) {
      entries.add(MapEntry('Mobília', displayPropertyFurnishingLabel));
    }
    if (condoFeeOnRequest) {
      entries.add(const MapEntry('Condomínio', 'A combinar'));
    } else if (condoFee != null && condoFee! > 0) {
      entries.add(MapEntry('Condomínio', '${formatCurrency(condoFee!)}/mês'));
    }
    if (propertyMonthlyCosts.isNotEmpty) {
      entries.add(
        MapEntry(
          'Custos extras',
          propertyMonthlyCosts.map((cost) => cost.displayLabel).join(', '),
        ),
      );
    }

    return entries;
  }

  List<MapEntry<String, String>> get customAttributeEntries {
    return customAttributes
        .where((attribute) => attribute.value.trim().isNotEmpty)
        .map((attribute) =>
            MapEntry(attribute.label.trim(), attribute.value.trim()))
        .toList();
  }

  List<String> get cardHighlights {
    final highlights = <String>[];

    if (displayCategoryTypeLabel.isNotEmpty) {
      highlights.add(displayCategoryTypeLabel);
    }

    for (final entry in customAttributeEntries) {
      final composed = '${entry.key}: ${entry.value}';
      if (!highlights.contains(composed)) {
        highlights.add(composed);
      }
      if (highlights.length >= 2) break;
    }

    return highlights;
  }

  String get cardHighlightLabel => cardHighlights.join(' • ');

  static String formatShortPersonName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last}';
  }

  static String formatCurrency(double price) {
    final parts = price.toStringAsFixed(2).split('.');
    final intPart = parts[0];
    final decPart = parts[1];
    final buffer = StringBuffer();

    for (var i = 0; i < intPart.length; i++) {
      final reverseIndex = intPart.length - i;
      buffer.write(intPart[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write('.');
      }
    }

    return 'R\$ ${buffer.toString()},$decPart';
  }

  static String _formatArea(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toStringAsFixed(0)} m²';
    }
    return '${value.toStringAsFixed(1).replaceAll('.', ',')} m²';
  }

  static String displayLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;
    return uiDisplayLabels[trimmed] ?? trimmed;
  }

  static String normalizeValue(String value) {
    const accents = {
      'a': ['a', 'A', 'á', 'Á', 'à', 'À', 'â', 'Â', 'ã', 'Ã'],
      'e': ['e', 'E', 'é', 'É', 'ê', 'Ê'],
      'i': ['i', 'I', 'í', 'Í'],
      'o': ['o', 'O', 'ó', 'Ó', 'ô', 'Ô', 'õ', 'Õ'],
      'u': ['u', 'U', 'ú', 'Ú'],
      'c': ['c', 'C', 'ç', 'Ç'],
    };

    var normalized = value.trim();
    accents.forEach((replacement, variants) {
      for (final variant in variants) {
        normalized = normalized.replaceAll(variant, replacement);
      }
    });
    return normalized.toLowerCase();
  }

  static String resolveCategoryValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return trimmed;

    final normalizedTarget = normalizeValue(trimmed);
    for (final categoryValue in categories) {
      if (normalizeValue(categoryValue) == normalizedTarget) {
        return categoryValue;
      }
    }

    return trimmed;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sellerId': sellerId,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'type': type,
      'intent': intent,
      'images': images,
      'imagePublicIds': imagePublicIds,
      'location': location,
      'sellerName': sellerName,
      'sellerAvatar': sellerAvatar,
      'createdAt': Timestamp.fromDate(createdAt),
      'km': km,
      'storeId': storeId,
      'storeName': storeName,
      'storeLogo': storeLogo,
      'sellerUserName': sellerUserName,
      'sellerUserAvatar': sellerUserAvatar,
      'oldPrice': oldPrice,
      'clickCount': clickCount,
      'lat': lat,
      'lng': lng,
      'servicePriceType': servicePriceType,
      'hourlyPrice': hourlyPrice,
      'isActive': isActive,
      'categoryType': categoryType,
      'categoryTypeCustomLabel': categoryTypeCustomLabel,
      'vehicleBrand': vehicleBrand,
      'vehicleModel': vehicleModel,
      'vehicleYear': vehicleYear,
      'vehicleOptionals': vehicleOptionals,
      'vehicleColor': vehicleColor,
      'vehicleFuelType': vehicleFuelType,
      'vehicleOwnerCount': vehicleOwnerCount,
      'propertyOfferType': propertyOfferType,
      'condoFee': condoFee,
      'condoFeeOnRequest': condoFeeOnRequest,
      'propertyMonthlyCosts':
          propertyMonthlyCosts.map((cost) => cost.toMap()).toList(),
      'propertyArea': propertyArea,
      'propertyBedrooms': propertyBedrooms,
      'propertyBathrooms': propertyBathrooms,
      'propertyParkingSpots': propertyParkingSpots,
      'propertyFurnishing': propertyFurnishing,
      'customAttributes': customAttributes.map((item) => item.toMap()).toList(),
    };
  }

  factory AdModel.fromMap(Map<String, dynamic> map) {
    return AdModel(
      id: map['id'] ?? '',
      sellerId: map['sellerId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? '',
      type: map['type'] ?? productType,
      intent: map['intent'] ?? intentSell,
      images: List<String>.from(map['images'] ?? []),
      imagePublicIds: List<String>.from(map['imagePublicIds'] ?? []),
      location: map['location'] ?? '',
      sellerName: map['sellerName'] ?? '',
      sellerAvatar: map['sellerAvatar'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      km: (map['km'] as num?)?.toInt(),
      storeId: map['storeId'],
      storeName: map['storeName'],
      storeLogo: map['storeLogo'],
      sellerUserName: map['sellerUserName'],
      sellerUserAvatar: map['sellerUserAvatar'],
      oldPrice: (map['oldPrice'] as num?)?.toDouble(),
      clickCount: (map['clickCount'] as num?)?.toInt() ?? 0,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      servicePriceType: map['servicePriceType'] ?? servicePriceFixed,
      hourlyPrice: (map['hourlyPrice'] as num?)?.toDouble(),
      isActive: map['isActive'] ?? true,
      categoryType: map['categoryType'],
      categoryTypeCustomLabel: map['categoryTypeCustomLabel'],
      vehicleBrand: map['vehicleBrand'],
      vehicleModel: map['vehicleModel'],
      vehicleYear: (map['vehicleYear'] as num?)?.toInt(),
      vehicleOptionals: List<String>.from(map['vehicleOptionals'] ?? const []),
      vehicleColor: map['vehicleColor'],
      vehicleFuelType: map['vehicleFuelType'],
      vehicleOwnerCount: (map['vehicleOwnerCount'] as num?)?.toInt(),
      propertyOfferType: map['propertyOfferType'],
      condoFee: (map['condoFee'] as num?)?.toDouble(),
      condoFeeOnRequest: map['condoFeeOnRequest'] ?? false,
      propertyMonthlyCosts:
          (map['propertyMonthlyCosts'] as List<dynamic>? ?? const [])
              .whereType<Map>()
              .map(
                (item) => PropertyExtraCost.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(),
      propertyArea: (map['propertyArea'] as num?)?.toDouble(),
      propertyBedrooms: (map['propertyBedrooms'] as num?)?.toInt(),
      propertyBathrooms: (map['propertyBathrooms'] as num?)?.toInt(),
      propertyParkingSpots: (map['propertyParkingSpots'] as num?)?.toInt(),
      propertyFurnishing: map['propertyFurnishing'],
      customAttributes: (map['customAttributes'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => AdAttribute.fromMap(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  AdModel copyWith({
    String? id,
    String? sellerId,
    String? title,
    String? description,
    double? price,
    String? category,
    String? type,
    String? intent,
    List<String>? images,
    List<String>? imagePublicIds,
    String? location,
    String? sellerName,
    String? sellerAvatar,
    DateTime? createdAt,
    int? km,
    String? storeId,
    String? storeName,
    String? storeLogo,
    String? sellerUserName,
    String? sellerUserAvatar,
    double? oldPrice,
    int? clickCount,
    double? lat,
    double? lng,
    String? servicePriceType,
    double? hourlyPrice,
    bool? isActive,
    String? categoryType,
    String? categoryTypeCustomLabel,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    List<String>? vehicleOptionals,
    String? vehicleColor,
    String? vehicleFuelType,
    int? vehicleOwnerCount,
    String? propertyOfferType,
    double? condoFee,
    bool? condoFeeOnRequest,
    List<PropertyExtraCost>? propertyMonthlyCosts,
    double? propertyArea,
    int? propertyBedrooms,
    int? propertyBathrooms,
    int? propertyParkingSpots,
    String? propertyFurnishing,
    List<AdAttribute>? customAttributes,
  }) {
    return AdModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      type: type ?? this.type,
      intent: intent ?? this.intent,
      images: images ?? this.images,
      imagePublicIds: imagePublicIds ?? this.imagePublicIds,
      location: location ?? this.location,
      sellerName: sellerName ?? this.sellerName,
      sellerAvatar: sellerAvatar ?? this.sellerAvatar,
      createdAt: createdAt ?? this.createdAt,
      km: km ?? this.km,
      storeId: storeId ?? this.storeId,
      storeName: storeName ?? this.storeName,
      storeLogo: storeLogo ?? this.storeLogo,
      sellerUserName: sellerUserName ?? this.sellerUserName,
      sellerUserAvatar: sellerUserAvatar ?? this.sellerUserAvatar,
      oldPrice: oldPrice ?? this.oldPrice,
      clickCount: clickCount ?? this.clickCount,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      servicePriceType: servicePriceType ?? this.servicePriceType,
      hourlyPrice: hourlyPrice ?? this.hourlyPrice,
      isActive: isActive ?? this.isActive,
      categoryType: categoryType ?? this.categoryType,
      categoryTypeCustomLabel:
          categoryTypeCustomLabel ?? this.categoryTypeCustomLabel,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleOptionals: vehicleOptionals ?? this.vehicleOptionals,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleFuelType: vehicleFuelType ?? this.vehicleFuelType,
      vehicleOwnerCount: vehicleOwnerCount ?? this.vehicleOwnerCount,
      propertyOfferType: propertyOfferType ?? this.propertyOfferType,
      condoFee: condoFee ?? this.condoFee,
      condoFeeOnRequest: condoFeeOnRequest ?? this.condoFeeOnRequest,
      propertyMonthlyCosts: propertyMonthlyCosts ?? this.propertyMonthlyCosts,
      propertyArea: propertyArea ?? this.propertyArea,
      propertyBedrooms: propertyBedrooms ?? this.propertyBedrooms,
      propertyBathrooms: propertyBathrooms ?? this.propertyBathrooms,
      propertyParkingSpots: propertyParkingSpots ?? this.propertyParkingSpots,
      propertyFurnishing: propertyFurnishing ?? this.propertyFurnishing,
      customAttributes: customAttributes ?? this.customAttributes,
    );
  }
}

class AdAttribute {
  const AdAttribute({
    required this.key,
    required this.label,
    required this.value,
  });

  final String key;
  final String label;
  final String value;

  factory AdAttribute.fromMap(Map<String, dynamic> map) {
    return AdAttribute(
      key: (map['key'] ?? '').toString(),
      label: (map['label'] ?? '').toString(),
      value: (map['value'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'label': label,
      'value': value,
    };
  }
}

class PropertyExtraCost {
  final String name;
  final double monthlyValue;
  final String billingPeriod;
  final bool priceOnRequest;

  const PropertyExtraCost({
    required this.name,
    required this.monthlyValue,
    this.billingPeriod = propertyCostPeriodMonthly,
    this.priceOnRequest = false,
  });

  static const String propertyCostPeriodMonthly = 'mensal';
  static const String propertyCostPeriodAnnual = 'anual';
  static const String propertyCostPeriodWeekly = 'semanal';
  static const String propertyCostPeriodContract = 'contrato';

  factory PropertyExtraCost.fromMap(Map<String, dynamic> map) {
    return PropertyExtraCost(
      name: (map['name'] ?? '').toString(),
      monthlyValue: (map['monthlyValue'] as num?)?.toDouble() ?? 0,
      billingPeriod:
          (map['billingPeriod'] ?? propertyCostPeriodMonthly).toString(),
      priceOnRequest: map['priceOnRequest'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'monthlyValue': monthlyValue,
      'billingPeriod': billingPeriod,
      'priceOnRequest': priceOnRequest,
    };
  }

  String get displayLabel => priceOnRequest
      ? '${name.trim()} (A combinar/${propertyCostPeriodSuffixes[billingPeriod] ?? 'mês'})'
      : '${name.trim()} (${AdModel.formatCurrency(monthlyValue)}/${propertyCostPeriodSuffixes[billingPeriod] ?? 'mês'})';
}

const Map<String, String> uiDisplayLabels = {
  'Eletronicos': 'Eletrônicos',
  'Veiculos': 'Veículos',
  'Imoveis': 'Imóveis',
  'Moveis': 'Móveis',
  'Servico': 'Serviço',
  'Servicos': 'Serviços',
  'Servicos Gerais': 'Serviços Gerais',
  'Assistencia tecnica': 'Assistência técnica',
  'Beleza e estetica': 'Beleza e estética',
  'Fretes e mudancas': 'Fretes e mudanças',
  'Reformas e manutencao': 'Reformas e manutenção',
  'Saude e bem-estar': 'Saúde e bem-estar',
  'Servicos pet': 'Serviços pet',
  'Outros servicos': 'Outros serviços',
  'Audio e fones': 'Áudio e fones',
  'Acessorios': 'Acessórios',
  'Utilitarios': 'Utilitários',
  'Pecas automotivas': 'Peças automotivas',
  'Acessorios veiculares': 'Acessórios veiculares',
  'Galpao': 'Galpão',
  'Sitio': 'Sítio',
  'Chacara': 'Chácara',
  'Sofa': 'Sofá',
  'Colchao': 'Colchão',
  'Comoda': 'Cômoda',
  'Calcas': 'Calças',
  'Tenis': 'Tênis',
  'Racao': 'Ração',
  'Aquarios': 'Aquários',
  'Passaros': 'Pássaros',
  'Colecionaveis': 'Colecionáveis',
  'Bebes': 'Bebês',
  'Utilidades domesticas': 'Utilidades domésticas',
  'Eletrodomesticos': 'Eletrodomésticos',
  'Musica': 'Música',
  'Reforco escolar': 'Reforço escolar',
  'Informatica': 'Informática',
  'Estetica facial': 'Estética facial',
  'Juridica': 'Jurídica',
  'Imobiliaria': 'Imobiliária',
  'Edicao de video': 'Edição de vídeo',
  'Designer grafico': 'Designer gráfico',
  'Gestao de trafego': 'Gestão de tráfego',
  'Decoracao': 'Decoração',
  'Frete rapido': 'Frete rápido',
  'Mudanca residencial': 'Mudança residencial',
  'Mudanca comercial': 'Mudança comercial',
  'Pos-obra': 'Pós-obra',
  'Montagem de moveis': 'Montagem de móveis',
  'Nutricao': 'Nutrição',
  'Digitacao': 'Digitação',
  'Traducao': 'Tradução',
  'Locucao': 'Locução',
  'Producao de conteudo': 'Produção de conteúdo',
  'Servicos gerais': 'Serviços gerais',
  'Usuario': 'Usuário',
  'Voce': 'Você',
  'Nao mobiliado': 'Não mobiliado',
  'Possui condominio e custos extras': 'Possui condomínio e custos extras',
  'Possui condominio': 'Possui condomínio',
  'Perfil de publicacao': 'Perfil de publicação',
  'Data de publicacao': 'Data de publicação',
  'Detalhes do anuncio': 'Detalhes do anúncio',
  'Resumo do anuncio': 'Resumo do anúncio',
  'Fotos do anuncio': 'Fotos do anúncio',
  'Cobranca': 'Cobrança',
  'Localizacao': 'Localização',
  'Descricao': 'Descrição',
  'Titulo': 'Título',
  'Preco': 'Preço',
  'Preco min': 'Preço mín',
  'Preco max': 'Preço máx',
  'Negocio': 'Negócio',
  'Area': 'Área',
  'Condominio': 'Condomínio',
  'Condominio do imovel': 'Condomínio do imóvel',
  'Mobilia': 'Mobília',
  'Ficha do veiculo': 'Ficha do veículo',
  'Filtros de veiculos': 'Filtros de veículos',
  'Recursos do veiculo': 'Recursos do veículo',
  'Tipo de combustivel': 'Tipo de combustível',
  'Quilometragem maxima': 'Quilometragem máxima',
  'Numero de proprietarios': 'Número de proprietários',
  'Valor por diaria (R\$)': 'Valor por diária (R\$)',
  'Preco (R\$)': 'Preço (R\$)',
  'Preco fixo (R\$)': 'Preço fixo (R\$)',
  'Valor por diaria': 'Valor por diária',
  'Nao informado': 'Não informado',
  'Vidro eletrico': 'Vidro elétrico',
  'Direcao hidraulica': 'Direção hidráulica',
  'Multimidia': 'Multimídia',
  'Camera de re': 'Câmera de ré',
  'Piloto automatico': 'Piloto automático',
  'Alcool': 'Álcool',
  'Combustivel': 'Combustível',
};

const List<String> productCategories = [
  'Eletronicos',
  'Veiculos',
  'Imoveis',
  'Moveis',
  'Roupas',
  'Esportes',
  'Animais',
  'Outros',
];

const List<String> serviceCategories = [
  'Assistencia tecnica',
  'Aulas e cursos',
  'Beleza e estetica',
  'Consultoria',
  'Design e marketing',
  'Eventos',
  'Fretes e mudancas',
  'Limpeza',
  'Reformas e manutencao',
  'Saude e bem-estar',
  'Servicos pet',
  'Vaga de emprego',
  'Outros servicos',
];

const Map<String, List<String>> categoryTypeOptions = {
  'Eletronicos': [
    'Celulares',
    'Computadores',
    'Notebooks',
    'Tablets',
    'Smartwatches',
    'TVs',
    'Videogames',
    'Audio e fones',
    'Cameras',
    'Acessorios',
  ],
  'Veiculos': [
    'Carros',
    'Motos',
    'Caminhonetes',
    'SUVs',
    'Vans',
    'Utilitarios',
    'Pecas automotivas',
    'Som automotivo',
    'Pneus e rodas',
    'Acessorios veiculares',
  ],
  'Imoveis': [
    'Apartamento',
    'Casa',
    'Terreno',
    'Cobertura',
    'Studio',
    'Kitnet',
    'Sobrado',
    'Loja comercial',
    'Sala comercial',
    'Galpao',
    'Sitio',
    'Chacara',
  ],
  'Moveis': [
    'Guarda-roupa',
    'Penteadeira',
    'Sofa',
    'Mesa de jantar',
    'Cama',
    'Colchao',
    'Escrivaninha',
    'Cadeira',
    'Estante',
    'Painel de TV',
    'Mesa de cabeceira',
    'Comoda',
  ],
  'Roupas': [
    'Camisas',
    'Blusas',
    'Calcas',
    'Jaquetas',
    'Vestidos',
    'Tenis',
    'Sapatos',
    'Bolsas',
    'Acessorios',
    'Moda infantil',
  ],
  'Esportes': [
    'Raquete de beach tennis',
    'Bola de basquete',
    'Bola de futebol',
    'Bicicleta',
    'Skate',
    'Patins',
    'Halteres',
    'Esteira',
    'Prancha',
    'Luvas e equipamentos',
  ],
  'Animais': [
    'Cachorro',
    'Gato',
    'Brinquedos pets',
    'Camas e casinhas',
    'Racao',
    'Aquarios',
    'Passaros',
    'Coleiras e guias',
    'Caixas de transporte',
    'Higiene pet',
  ],
  'Outros': [
    'Colecionaveis',
    'Instrumentos musicais',
    'Papelaria',
    'Brinquedos',
    'Bebes',
    'Utilidades domesticas',
    'Itens diversos',
  ],
  'Assistencia tecnica': [
    'Celular',
    'Notebook',
    'Computador',
    'TV',
    'Videogame',
    'Eletrodomesticos',
  ],
  'Aulas e cursos': [
    'Idiomas',
    'Musica',
    'Reforco escolar',
    'Informatica',
    'Vestibular',
    'Aulas particulares',
  ],
  'Beleza e estetica': [
    'Cabelo',
    'Manicure',
    'Maquiagem',
    'Designer de sobrancelhas',
    'Massagem',
    'Estetica facial',
  ],
  'Consultoria': [
    'Financeira',
    'Juridica',
    'Empresarial',
    'Carreira',
    'Marketing',
    'Imobiliaria',
  ],
  'Design e marketing': [
    'Identidade visual',
    'Social media',
    'Edicao de video',
    'Designer grafico',
    'Gestao de trafego',
    'Web design',
  ],
  'Eventos': [
    'Fotografia',
    'Filmagem',
    'Decoracao',
    'Buffet',
    'DJ',
    'Cerimonial',
  ],
  'Fretes e mudancas': [
    'Frete rapido',
    'Mudanca residencial',
    'Mudanca comercial',
    'Carreto',
    'Montagem e desmontagem',
  ],
  'Limpeza': [
    'Diarista',
    'Faxina pesada',
    'Pos-obra',
    'Limpeza comercial',
    'Lavagem de estofados',
  ],
  'Reformas e manutencao': [
    'Pintura',
    'Eletricista',
    'Encanador',
    'Pedreiro',
    'Gesso e drywall',
    'Montagem de moveis',
  ],
  'Saude e bem-estar': [
    'Personal trainer',
    'Fisioterapia',
    'Psicologia',
    'Nutricao',
    'Cuidador',
    'Terapias',
  ],
  'Servicos pet': [
    'Banho e tosa',
    'Passeador',
    'Adestramento',
    'Hospedagem',
    'Pet sitter',
    'Transporte pet',
  ],
  'Vaga de emprego': [
    'Atendimento',
    'Vendas',
    'Administrativo',
    'Logistica',
    'Informatica',
    'Servicos gerais',
  ],
  'Outros servicos': [
    'Digitacao',
    'Assistente virtual',
    'Traducao',
    'Locucao',
    'Producao de conteudo',
    'Servicos gerais',
  ],
};

const Map<String, String> propertyOfferTypeLabels = {
  AdModel.propertyOfferSale: 'Venda',
  AdModel.propertyOfferRent: 'Aluguel',
};

const Map<String, String> propertyExtraModeLabels = {
  AdModel.propertyExtraCondoAndCosts: 'Possui condomínio e custos extras',
  AdModel.propertyExtraCosts: 'Possui custos extras',
  AdModel.propertyExtraCondo: 'Possui condomínio',
  AdModel.propertyExtraNone: 'Apenas aluguel',
};

const Map<String, String> propertyFurnishingLabels = {
  AdModel.propertyFurnishingUnfurnished: 'Não mobiliado',
  AdModel.propertyFurnishingSemi: 'Semi mobiliado',
  AdModel.propertyFurnishingFurnished: 'Mobiliado',
};

const Map<String, String> propertyCostPeriodLabels = {
  PropertyExtraCost.propertyCostPeriodMonthly: 'Custo mensal',
  PropertyExtraCost.propertyCostPeriodAnnual: 'Custo anual',
  PropertyExtraCost.propertyCostPeriodWeekly: 'Custo semanal',
  PropertyExtraCost.propertyCostPeriodContract: 'Por contrato',
};

const Map<String, String> propertyCostPeriodSuffixes = {
  PropertyExtraCost.propertyCostPeriodMonthly: 'mês',
  PropertyExtraCost.propertyCostPeriodAnnual: 'ano',
  PropertyExtraCost.propertyCostPeriodWeekly: 'semana',
  PropertyExtraCost.propertyCostPeriodContract: 'contrato',
};

const List<String> categories = [
  ...productCategories,
  ...serviceCategories,
];

const List<String> servicePricingModes = [
  AdModel.servicePriceFixed,
  AdModel.servicePriceHourly,
  AdModel.servicePriceFixedPlusHourly,
  AdModel.servicePriceDaily,
];

const Map<String, String> servicePricingModeLabels = {
  AdModel.servicePriceFixed: 'Valor fixo',
  AdModel.servicePriceHourly: 'Por hora',
  AdModel.servicePriceFixedPlusHourly: 'Fixo + hora',
  AdModel.servicePriceDaily: 'Por diária',
};

const List<String> vehicleOptionalSuggestions = [
  'Vidro eletrico',
  'Ar-condicionado',
  'Direcao hidraulica',
  'Multimidia',
  'Camera de re',
  'Airbag',
  'ABS',
  'Bancos em couro',
  'Sensor de estacionamento',
  'Teto solar',
  'Piloto automatico',
  'Outro +',
];

const List<String> vehicleColorOptions = [
  'Preto',
  'Branco',
  'Prata',
  'Cinza',
  'Vermelho',
  'Azul',
  'Outro +',
];

const List<String> vehicleFuelOptions = [
  'Gasolina',
  'Alcool',
  'Flex',
  'Diesel',
  'Outro +',
];

List<AdModel> sampleAds = [
  AdModel(
    id: '1',
    title: 'iPhone 14 Pro Max 256GB',
    description:
        'Excelente estado, sem arranhões, com caixa original e todos os acessórios. Bateria 98%. Comprado há 8 meses.',
    price: 4500.00,
    category: 'Eletronicos',
    type: 'produto',
    images: const [],
    location: 'Curitiba, PR',
    sellerName: 'Carlos Silva',
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
  ),
  AdModel(
    id: '2',
    title: 'Consultoria de Design de Interiores',
    description:
        'Transforme seu ambiente com uma consultoria personalizada. Projetos 3D e escolha de materiais.',
    price: 350.00,
    category: 'Design',
    type: 'servico',
    servicePriceType: AdModel.servicePriceFixedPlusHourly,
    hourlyPrice: 60,
    images: const [],
    location: 'Sao Paulo, SP',
    sellerName: 'Ana Paula',
    createdAt: DateTime.now().subtract(const Duration(hours: 5)),
  ),
  AdModel(
    id: '3',
    title: 'Honda Civic 2020 Touring',
    description:
        'Único dono, todas as revisões na concessionária. Teto solar, bancos em couro, som premium.',
    price: 125000.00,
    category: 'Veiculos',
    type: 'produto',
    images: const [],
    location: 'Belo Horizonte, MG',
    sellerName: 'Marcos Oliveira',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    km: 35000,
    vehicleBrand: 'Honda',
    vehicleModel: 'Civic Touring',
    vehicleYear: 2020,
    vehicleColor: 'Prata',
    vehicleFuelType: 'Flex',
    vehicleOwnerCount: 1,
    vehicleOptionals: ['Teto solar', 'Bancos em couro', 'Multimidia'],
  ),
];
