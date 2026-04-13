import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/ad_model.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ad_card.dart';
import '../widgets/marketplace_controls.dart';
import 'ad_detail_screen.dart';
import 'favorites_screen.dart';
import 'location_picker_screen.dart';
import 'seller_profile_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({
    super.key,
    required this.initialQuery,
    required this.ads,
    required this.filters,
    required this.locationScope,
    required this.locationRegionKey,
    required this.searchLat,
    required this.searchLng,
    required this.searchRadiusKm,
    required this.locationLabel,
  });

  final String initialQuery;
  final List<AdModel> ads;
  final MarketplaceFilters filters;
  final String locationScope;
  final String locationRegionKey;
  final double searchLat;
  final double searchLng;
  final int searchRadiusKm;
  final String locationLabel;

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final Distance _distance = const Distance();
  final FirestoreService _firestore = FirestoreService();
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  late MarketplaceFilters _filters;
  late String _locationScope;
  late String _locationRegionKey;
  late double _searchLat;
  late double _searchLng;
  late int _searchRadiusKm;
  late String _locationLabel;
  late String _query;

  List<UserModel> _userSearchSuggestions = [];
  bool _isLoadingUserSearch = false;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    _filters = widget.filters;
    _locationScope = widget.locationScope;
    _locationRegionKey = widget.locationRegionKey;
    _searchLat = widget.searchLat;
    _searchLng = widget.searchLng;
    _searchRadiusKm = widget.searchRadiusKm;
    _locationLabel = widget.locationLabel;
    _searchController = TextEditingController(text: _query);
    _searchFocusNode = FocusNode()
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool get _showSuggestions {
    final trimmed = _searchController.text.trim();
    return _searchFocusNode.hasFocus && trimmed.isNotEmpty;
  }

  Future<void> _onSearchChanged(String value) async {
    final trimmed = value.trim();
    setState(() {
      if (trimmed.isEmpty) {
        _userSearchSuggestions = [];
        _isLoadingUserSearch = false;
      } else {
        _isLoadingUserSearch = true;
      }
    });

    if (trimmed.isEmpty) return;

    final suggestions = await _firestore.searchUsersByName(trimmed, limit: 3);
    if (!mounted || _searchController.text.trim() != trimmed) return;

    setState(() {
      _userSearchSuggestions = suggestions;
      _isLoadingUserSearch = false;
    });
  }

  void _submitSearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    context.read<UserProvider>().saveSearchQuery(trimmed);
    setState(() {
      _query = trimmed;
      _userSearchSuggestions = [];
      _isLoadingUserSearch = false;
      _searchController.value = TextEditingValue(
        text: trimmed,
        selection: TextSelection.collapsed(offset: trimmed.length),
      );
    });
    _searchFocusNode.unfocus();
  }

  List<AdModel> get _baseAds {
    final source = widget.ads.isEmpty ? sampleAds : widget.ads;
    return source.where((ad) => ad.intent == AdModel.intentSell).toList();
  }

  List<String> _searchTextSuggestions(List<String> recentSearches) {
    final rawQuery = _searchController.text.trim();
    final query = AdModel.normalizeValue(rawQuery);
    if (query.isEmpty) return const [];

    final suggestions = <String>[rawQuery];
    final seen = <String>{query};

    void addSuggestion(String value) {
      final trimmed = value.trim();
      final normalized = AdModel.normalizeValue(trimmed);
      if (trimmed.isEmpty || normalized.isEmpty || seen.contains(normalized)) {
        return;
      }
      suggestions.add(trimmed);
      seen.add(normalized);
    }

    final oneWordCandidates = <String>[];
    final titleCandidates = <String>[];

    for (final previous in recentSearches) {
      final normalized = AdModel.normalizeValue(previous);
      if (!normalized.contains(query)) continue;
      if (previous.trim().contains(' ')) {
        titleCandidates.add(previous);
      } else {
        oneWordCandidates.add(previous);
      }
    }

    for (final ad in _baseAds) {
      final title = ad.title.trim();
      final normalizedTitle = AdModel.normalizeValue(title);
      if (!normalizedTitle.contains(query)) continue;

      titleCandidates.add(title);

      for (final word in title.split(RegExp(r'\s+'))) {
        final cleaned = word.trim();
        final normalizedWord = AdModel.normalizeValue(cleaned);
        if (normalizedWord.startsWith(query)) {
          oneWordCandidates.add(cleaned);
        }
      }
    }

    oneWordCandidates.sort((a, b) {
      final aNorm = AdModel.normalizeValue(a);
      final bNorm = AdModel.normalizeValue(b);
      final aStarts = aNorm.startsWith(query);
      final bStarts = bNorm.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.length.compareTo(b.length);
    });

    titleCandidates.sort((a, b) {
      final aNorm = AdModel.normalizeValue(a);
      final bNorm = AdModel.normalizeValue(b);
      final aStarts = aNorm.startsWith(query);
      final bStarts = bNorm.startsWith(query);
      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.length.compareTo(b.length);
    });

    for (final candidate in oneWordCandidates) {
      addSuggestion(candidate);
      if (suggestions.length >= 2) break;
    }

    for (final candidate in titleCandidates) {
      addSuggestion(candidate);
      if (suggestions.length >= 8) break;
    }

    return suggestions;
  }

  Widget _buildSearchSuggestions(bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? AppTheme.blackCard : Colors.white;
    final borderColor = isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB);
    final recentSearches = context.watch<UserProvider>().recentSearches;
    final textSuggestions = _searchTextSuggestions(recentSearches);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      children: [
        if (_isLoadingUserSearch)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: LinearProgressIndicator(
              minHeight: 2,
              color: AppTheme.facebookBlue,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Pesquisar por',
            style: GoogleFonts.roboto(
              color: Colors.grey,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ...textSuggestions.map(
          (suggestion) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: Text(
              suggestion,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.roboto(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            trailing: const Icon(
              Icons.north_west_rounded,
              color: Colors.grey,
              size: 18,
            ),
            onTap: () => _submitSearch(suggestion),
          ),
        ),
        if (_userSearchSuggestions.isNotEmpty) const SizedBox(height: 10),
        if (_userSearchSuggestions.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Usuarios',
              style: GoogleFonts.roboto(
                color: Colors.grey,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ..._userSearchSuggestions.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: borderColor),
                ),
                tileColor: cardColor,
                leading: CircleAvatar(
                  backgroundColor:
                      AppTheme.facebookBlue.withValues(alpha: 0.12),
                  backgroundImage: user.profilePhoto != null &&
                          user.profilePhoto!.trim().isNotEmpty
                      ? NetworkImage(user.profilePhoto!)
                      : null,
                  child: user.profilePhoto == null ||
                          user.profilePhoto!.trim().isEmpty
                      ? Text(
                          user.firstName.isNotEmpty
                              ? user.firstName[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.roboto(
                            color: AppTheme.facebookBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  user.fullName,
                  style: GoogleFonts.roboto(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  user.address.city.isNotEmpty
                      ? '${user.address.city}, ${user.address.state}'
                      : 'Perfil de usuario',
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontSize: 12.5,
                  ),
                ),
                onTap: () {
                  _searchFocusNode.unfocus();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SellerProfileScreen(
                        sellerId: user.uid,
                        sellerName: user.fullName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<AdModel> get _titleMatches {
    final normalizedQuery = AdModel.normalizeValue(_query);
    if (normalizedQuery.isEmpty) return const [];

    final matches = _baseAds.where((ad) {
      final normalizedTitle = AdModel.normalizeValue(ad.title);
      return normalizedTitle.contains(normalizedQuery);
    }).toList();

    return _sortAds(
      matches.where(_matchesSelectedLocation).where(_matchesFilters).toList(),
    );
  }

  List<AdModel> get _relatedMatches {
    final titleMatches = _titleMatches;
    if (titleMatches.isEmpty) return const [];

    final matchedIds = titleMatches.map((ad) => ad.id).toSet();
    final matchedCategories = titleMatches
        .map((ad) => AdModel.normalizeValue(ad.category))
        .where((value) => value.isNotEmpty)
        .toSet();

    final related = _baseAds.where((ad) {
      if (matchedIds.contains(ad.id)) return false;

      final normalizedCategory = AdModel.normalizeValue(ad.category);
      final normalizedTitle = AdModel.normalizeValue(ad.title);
      return matchedCategories.contains(normalizedCategory) ||
          normalizedTitle.contains(AdModel.normalizeValue(_query));
    }).toList();

    return _sortAds(
      related.where(_matchesSelectedLocation).where(_matchesFilters).toList(),
    );
  }

  double? _distanceKmForAd(AdModel ad) {
    if (ad.lat == null || ad.lng == null) return null;
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(_searchLat, _searchLng),
      LatLng(ad.lat!, ad.lng!),
    );
  }

  String _normalizeRegionValue(String value) {
    return AdModel.normalizeValue(value);
  }

  bool _matchesStateLocation(AdModel ad, String regionKey) {
    final normalizedLocation = _normalizeRegionValue(ad.location);
    final aliasesByState = <String, List<String>>{
      'pr': ['pr', 'parana'],
      'sp': ['sp', 'sao paulo'],
      'rj': ['rj', 'rio de janeiro'],
      'mg': ['mg', 'minas gerais'],
      'sc': ['sc', 'santa catarina'],
      'rs': ['rs', 'rio grande do sul'],
      'ba': ['ba', 'bahia'],
      'go': ['go', 'goias'],
      'df': ['df', 'distrito federal', 'brasilia'],
      'br': ['brasil'],
    };
    final aliases = aliasesByState[regionKey] ?? [regionKey];
    return aliases.any(
      (alias) =>
          normalizedLocation.contains(', $alias') ||
          normalizedLocation.endsWith(alias) ||
          normalizedLocation.contains(alias),
    );
  }

  bool _matchesSelectedLocation(AdModel ad) {
    if (_locationScope == 'country') {
      return true;
    }
    if (_locationScope == 'state') {
      return _matchesStateLocation(ad, _locationRegionKey);
    }

    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm != null) {
      return distanceKm <= _searchRadiusKm;
    }

    final selectedRegion =
        _normalizeRegionValue(_locationLabel.split(' - ').first);
    final adLocation = _normalizeRegionValue(ad.location);
    if (selectedRegion.isEmpty || adLocation.isEmpty) {
      return false;
    }
    return adLocation.contains(selectedRegion) ||
        selectedRegion.contains(adLocation);
  }

  bool _matchesFilters(AdModel ad) {
    return _filters.matchesAd(ad);
  }

  List<AdModel> _sortAds(List<AdModel> ads) {
    final sorted = List<AdModel>.from(ads);
    final normalizedQuery = AdModel.normalizeValue(_query);

    sorted.sort((a, b) {
      final aTitle = AdModel.normalizeValue(a.title);
      final bTitle = AdModel.normalizeValue(b.title);
      final aStarts = aTitle.startsWith(normalizedQuery);
      final bStarts = bTitle.startsWith(normalizedQuery);
      if (aStarts != bStarts) return aStarts ? -1 : 1;

      final aDistance = _distanceKmForAd(a) ?? double.infinity;
      final bDistance = _distanceKmForAd(b) ?? double.infinity;
      final distanceCompare = aDistance.compareTo(bDistance);
      if (distanceCompare != 0) return distanceCompare;

      return b.createdAt.compareTo(a.createdAt);
    });

    switch (_filters.sort) {
      case MarketplaceSort.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case MarketplaceSort.priceLow:
        sorted.sort((a, b) => a.price.compareTo(b.price));
        break;
      case MarketplaceSort.priceHigh:
        sorted.sort((a, b) => b.price.compareTo(a.price));
        break;
      case MarketplaceSort.recommended:
        sorted.sort((a, b) {
          final clickDiff = b.clickCount.compareTo(a.clickCount);
          if (clickDiff != 0) return clickDiff;
          return b.createdAt.compareTo(a.createdAt);
        });
        break;
    }

    return sorted;
  }

  int? _roundedDistanceKmForAd(AdModel ad) {
    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm == null) return null;
    if (distanceKm > 0 && distanceKm < 1) return 1;
    return distanceKm.round();
  }

  String _badgeLabelForAd(AdModel ad) {
    if (_locationScope == 'state') return 'Na regiao';
    if (_locationScope == 'country') return 'Brasil';
    final distanceKm = _distanceKmForAd(ad);
    if (distanceKm == null) return 'Nas proximidades';
    return distanceKm > _searchRadiusKm ? 'Fora do raio' : 'Nas proximidades';
  }

  SliverGridDelegate _gridDelegate(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 980
        ? 4
        : width >= 720
            ? 3
            : 2;

    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      mainAxisExtent: 236,
    );
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLat: _searchLat,
          initialLng: _searchLng,
          initialRadiusKm: _searchRadiusKm,
          initialLabel: _locationLabel.split(' - ').first,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _searchLat = result.lat;
      _searchLng = result.lng;
      _searchRadiusKm = result.radiusKm;
      _locationScope = result.scope;
      _locationRegionKey = _normalizeRegionValue(result.regionKey);
      _locationLabel = result.scope == 'city'
          ? '${result.label} - ${result.radiusKm}km'
          : result.label;
    });

    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user != null && result.scope == 'city') {
      await userProvider.updateSearchArea(
        address: user.address.copyWith(
          lat: result.lat,
          lng: result.lng,
        ),
        searchRadius: result.radiusKm,
      );
    } else {
      userProvider.notifyMarketplaceChanged();
    }
  }

  // ignore: unused_element
  Future<void> _openFiltersLegacy() async {
    final minCtrl = TextEditingController(
      text: _filters.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: _filters.maxPrice?.toStringAsFixed(0) ?? '',
    );
    final kmCtrl =
        TextEditingController(text: _filters.maxKm?.toString() ?? '');
    final yearMinCtrl =
        TextEditingController(text: _filters.minYear?.toString() ?? '');
    final yearMaxCtrl =
        TextEditingController(text: _filters.maxYear?.toString() ?? '');
    MarketplaceFilters temp = _filters;
    final allCategories = <String>['', ...categories];
    const manufacturers = [
      'Volkswagen',
      'Chevrolet',
      'Fiat',
      'Ford',
      'Toyota',
      'Honda',
      'Hyundai',
      'Renault',
      'Nissan',
      'Jeep',
      'Peugeot',
      'Citroen',
      'Mitsubishi',
      'BMW',
      'Mercedes-Benz',
      'Audi',
      'Kia',
      'Volvo',
      'Porsche',
      'Land Rover',
      'BYD',
      'Chery',
      'JAC',
      'Ram',
      'Suzuki',
    ];
    const fuels = [
      'Gasolina',
      'Etanol',
      'Flex',
      'Diesel',
      'Eletrico',
      'Hibrido',
      'GNV',
    ];
    const transmissions = ['Manual', 'Automatico', 'CVT'];
    const vehicleFeatures = [
      'Ar-condicionado',
      'Direcao hidraulica',
      'Airbag',
      'ABS',
      'Multimidia',
      'Camera de re',
    ];

    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.blackCard
          : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isVehicle =
              AdModel.normalizeValue(temp.category ?? '') == 'veiculos';
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros',
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _dropdown<MarketplaceSort>(
                      'Classificar por',
                      temp.sort,
                      MarketplaceSort.values,
                      (v) =>
                          setModalState(() => temp = temp.copyWith(sort: v!)),
                      (v) => {
                        MarketplaceSort.recommended: 'Relevância',
                        MarketplaceSort.newest: 'Mais recentes',
                        MarketplaceSort.priceLow: 'Menor preço',
                        MarketplaceSort.priceHigh: 'Maior preço',
                      }[v]!,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            'Preço mín',
                            minCtrl,
                            TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _input(
                            'Preço máx',
                            maxCtrl,
                            TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown<PublicationDateFilter>(
                      'Data de publicação',
                      temp.publicationDate,
                      PublicationDateFilter.values,
                      (v) => setModalState(
                        () => temp = temp.copyWith(publicationDate: v!),
                      ),
                      (v) => {
                        PublicationDateFilter.any: 'Qualquer data',
                        PublicationDateFilter.last24h: 'Últimas 24h',
                        PublicationDateFilter.last7days: 'Últimos 7 dias',
                        PublicationDateFilter.last30days: 'Últimos 30 dias',
                      }[v]!,
                    ),
                    const SizedBox(height: 10),
                    _dropdown<String>(
                      'Condição',
                      temp.condition ?? '',
                      const ['', 'Novo', 'Seminovo', 'Usado'],
                      (v) => setModalState(
                        () => temp = temp.copyWith(
                          condition: v,
                          resetCondition: v == null || v.isEmpty,
                        ),
                      ),
                      (v) => v.isEmpty ? 'Todas' : AdModel.displayLabel(v),
                    ),
                    const SizedBox(height: 10),
                    _dropdown<String>(
                      'Categoria',
                      temp.category ?? '',
                      allCategories,
                      (v) => setModalState(
                        () => temp = temp.copyWith(
                          category: v,
                          resetCategory: v == null || v.isEmpty,
                        ),
                      ),
                      (v) => v.isEmpty ? 'Todas' : v,
                    ),
                    if (isVehicle) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Filtros de veículos',
                        style: GoogleFonts.roboto(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _input(
                              'Ano mín',
                              yearMinCtrl,
                              TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _input(
                              'Ano máx',
                              yearMaxCtrl,
                              TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Fabricante',
                        temp.manufacturer ?? '',
                        const ['', ...manufacturers],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            manufacturer: v,
                            resetManufacturer: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : v,
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Tipo de combustível',
                        temp.fuelType ?? '',
                        const ['', ...fuels],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            fuelType: v,
                            resetFuelType: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : v,
                      ),
                      const SizedBox(height: 10),
                      _input(
                        'Quilometragem máxima',
                        kmCtrl,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Tipo de transmissão',
                        temp.transmission ?? '',
                        const ['', ...transmissions],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            transmission: v,
                            resetTransmission: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : v,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Recursos do veículo',
                        style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                      ),
                      Wrap(
                        spacing: 8,
                        children: vehicleFeatures.map((feature) {
                          final selected =
                              temp.vehicleFeatures.contains(feature);
                          return FilterChip(
                            label: Text(
                              AdModel.displayLabel(feature),
                              style: GoogleFonts.roboto(),
                            ),
                            selected: selected,
                            onSelected: (value) => setModalState(() {
                              final next =
                                  Set<String>.from(temp.vehicleFeatures);
                              value ? next.add(feature) : next.remove(feature);
                              temp = temp.copyWith(vehicleFeatures: next);
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              MarketplaceFilters.empty,
                            ),
                            child: const Text('Limpar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = temp.copyWith(
                                minPrice: double.tryParse(minCtrl.text.trim()),
                                maxPrice: double.tryParse(maxCtrl.text.trim()),
                                maxKm: int.tryParse(kmCtrl.text.trim()),
                                minYear: int.tryParse(yearMinCtrl.text.trim()),
                                maxYear: int.tryParse(yearMaxCtrl.text.trim()),
                                resetMinPrice: minCtrl.text.trim().isEmpty,
                                resetMaxPrice: maxCtrl.text.trim().isEmpty,
                                resetMaxKm: kmCtrl.text.trim().isEmpty,
                                resetMinYear: yearMinCtrl.text.trim().isEmpty,
                                resetMaxYear: yearMaxCtrl.text.trim().isEmpty,
                              );
                              Navigator.pop(context, parsed);
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _filters = result);
    }
  }

  Future<void> _openFilters() async {
    final minCtrl = TextEditingController(
      text: _filters.minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxCtrl = TextEditingController(
      text: _filters.maxPrice?.toStringAsFixed(0) ?? '',
    );
    final kmCtrl =
        TextEditingController(text: _filters.maxKm?.toString() ?? '');
    final yearMinCtrl = TextEditingController(
      text: _filters.minYear?.toString() ?? '',
    );
    final yearMaxCtrl = TextEditingController(
      text: _filters.maxYear?.toString() ?? '',
    );
    MarketplaceFilters temp = _filters;
    final allCategories = <String>['', ...categories];
    const typeOptions = ['', AdModel.productType, AdModel.serviceType];
    const propertyOfferOptions = [
      '',
      AdModel.propertyOfferSale,
      AdModel.propertyOfferRent,
    ];
    const manufacturers = [
      'Volkswagen',
      'Chevrolet',
      'Fiat',
      'Ford',
      'Toyota',
      'Honda',
      'Hyundai',
      'Renault',
      'Nissan',
      'Jeep',
      'Peugeot',
      'Citroen',
      'Mitsubishi',
      'BMW',
      'Mercedes-Benz',
      'Audi',
      'Kia',
      'Volvo',
      'Porsche',
      'Land Rover',
      'BYD',
      'Chery',
      'JAC',
      'Ram',
      'Suzuki',
    ];
    const fuels = [
      'Gasolina',
      'Etanol',
      'Flex',
      'Diesel',
      'Eletrico',
      'Hibrido',
      'GNV',
    ];
    const vehicleFeatures = [
      'Ar-condicionado',
      'Direcao hidraulica',
      'Airbag',
      'ABS',
      'Multimidia',
      'Camera de re',
    ];

    final result = await showModalBottomSheet<MarketplaceFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppTheme.blackCard
          : Colors.white,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final selectedCategory =
              AdModel.resolveCategoryValue(temp.category ?? '');
          final normalizedCategory = AdModel.normalizeValue(selectedCategory);
          final selectedType = temp.adType ?? '';
          final isProductContext =
              selectedType.isEmpty || selectedType == AdModel.productType;
          final isVehicle =
              normalizedCategory == 'veiculos' && isProductContext;
          final isProperty =
              normalizedCategory == 'imoveis' && isProductContext;

          void clearVehicleFilters() {
            kmCtrl.clear();
            yearMinCtrl.clear();
            yearMaxCtrl.clear();
            temp = temp.copyWith(
              manufacturer: '',
              fuelType: '',
              transmission: '',
              vehicleFeatures: <String>{},
              resetManufacturer: true,
              resetFuelType: true,
              resetTransmission: true,
              resetMaxKm: true,
              resetMinYear: true,
              resetMaxYear: true,
            );
          }

          void syncDependentFilters() {
            final currentCategory = AdModel.normalizeValue(
              AdModel.resolveCategoryValue(temp.category ?? ''),
            );
            final currentType = temp.adType ?? '';
            final currentIsProductContext =
                currentType.isEmpty || currentType == AdModel.productType;

            if (!(currentCategory == 'veiculos' && currentIsProductContext)) {
              clearVehicleFilters();
            }
            if (!(currentCategory == 'imoveis' && currentIsProductContext)) {
              temp = temp.copyWith(
                propertyOfferType: '',
                resetPropertyOfferType: true,
              );
            }
          }

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filtros',
                      style: GoogleFonts.roboto(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _dropdown<MarketplaceSort>(
                      'Classificar por',
                      temp.sort,
                      MarketplaceSort.values,
                      (v) => setModalState(
                        () => temp = temp.copyWith(sort: v!),
                      ),
                      (v) => {
                        MarketplaceSort.recommended: 'Relevância',
                        MarketplaceSort.newest: 'Mais recentes',
                        MarketplaceSort.priceLow: 'Menor preço',
                        MarketplaceSort.priceHigh: 'Maior preço',
                      }[v]!,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _input(
                            'Preço mín',
                            minCtrl,
                            TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _input(
                            'Preço máx',
                            maxCtrl,
                            TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _dropdown<PublicationDateFilter>(
                      'Data de publicação',
                      temp.publicationDate,
                      PublicationDateFilter.values,
                      (v) => setModalState(
                        () => temp = temp.copyWith(publicationDate: v!),
                      ),
                      (v) => {
                        PublicationDateFilter.any: 'Qualquer data',
                        PublicationDateFilter.last24h: 'Últimas 24h',
                        PublicationDateFilter.last7days: 'Últimos 7 dias',
                        PublicationDateFilter.last30days: 'Últimos 30 dias',
                      }[v]!,
                    ),
                    const SizedBox(height: 10),
                    _dropdown<String>(
                      'Tipo',
                      temp.adType ?? '',
                      typeOptions,
                      (v) => setModalState(() {
                        temp = temp.copyWith(
                          adType: v,
                          resetAdType: v == null || v.isEmpty,
                        );
                        syncDependentFilters();
                      }),
                      (v) => v.isEmpty ? 'Todos' : AdModel.displayLabel(v),
                    ),
                    const SizedBox(height: 10),
                    _dropdown<String>(
                      'Categoria',
                      temp.category ?? '',
                      allCategories,
                      (v) => setModalState(() {
                        temp = temp.copyWith(
                          category: v,
                          resetCategory: v == null || v.isEmpty,
                        );
                        syncDependentFilters();
                      }),
                      (v) => v.isEmpty ? 'Todas' : AdModel.displayLabel(v),
                    ),
                    if (isProperty) ...[
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Negócio',
                        temp.propertyOfferType ?? '',
                        propertyOfferOptions,
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            propertyOfferType: v,
                            resetPropertyOfferType: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : AdModel.displayLabel(v),
                      ),
                    ],
                    if (isVehicle) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Filtros de veículos',
                        style: GoogleFonts.roboto(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _input(
                              'Ano mín',
                              yearMinCtrl,
                              TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _input(
                              'Ano máx',
                              yearMaxCtrl,
                              TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Fabricante',
                        temp.manufacturer ?? '',
                        const ['', ...manufacturers],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            manufacturer: v,
                            resetManufacturer: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : v,
                      ),
                      const SizedBox(height: 10),
                      _dropdown<String>(
                        'Tipo de combustível',
                        temp.fuelType ?? '',
                        const ['', ...fuels],
                        (v) => setModalState(
                          () => temp = temp.copyWith(
                            fuelType: v,
                            resetFuelType: v == null || v.isEmpty,
                          ),
                        ),
                        (v) => v.isEmpty ? 'Todos' : AdModel.displayLabel(v),
                      ),
                      const SizedBox(height: 10),
                      _input(
                        'Quilometragem máxima',
                        kmCtrl,
                        TextInputType.number,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Recursos do veículo',
                        style: GoogleFonts.roboto(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: vehicleFeatures.map((feature) {
                          final selected =
                              temp.vehicleFeatures.contains(feature);
                          return FilterChip(
                            label: Text(
                              AdModel.displayLabel(feature),
                              style: GoogleFonts.roboto(),
                            ),
                            selected: selected,
                            onSelected: (value) => setModalState(() {
                              final next =
                                  Set<String>.from(temp.vehicleFeatures);
                              value ? next.add(feature) : next.remove(feature);
                              temp = temp.copyWith(vehicleFeatures: next);
                            }),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(
                              context,
                              MarketplaceFilters.empty,
                            ),
                            child: const Text('Limpar'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final parsed = temp.copyWith(
                                minPrice: double.tryParse(minCtrl.text.trim()),
                                maxPrice: double.tryParse(maxCtrl.text.trim()),
                                maxKm: int.tryParse(kmCtrl.text.trim()),
                                minYear: int.tryParse(yearMinCtrl.text.trim()),
                                maxYear: int.tryParse(yearMaxCtrl.text.trim()),
                                resetMinPrice: minCtrl.text.trim().isEmpty,
                                resetMaxPrice: maxCtrl.text.trim().isEmpty,
                                resetMaxKm: kmCtrl.text.trim().isEmpty,
                                resetMinYear: yearMinCtrl.text.trim().isEmpty,
                                resetMaxYear: yearMaxCtrl.text.trim().isEmpty,
                              );
                              Navigator.pop(context, parsed);
                            },
                            child: const Text('Aplicar'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _filters = result);
    }
  }

  Widget _input(
    String label,
    TextEditingController controller,
    TextInputType keyboardType,
  ) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }

  Widget _dropdown<T>(
    String label,
    T value,
    List<T> items,
    ValueChanged<T?> onChanged,
    String Function(T) labelOf,
  ) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<T>(
              value: item,
              child: Text(labelOf(item)),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.black : AppTheme.lightBg;
    final titleMatches = _titleMatches;
    final relatedMatches = _relatedMatches;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.black : Colors.white,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Expanded(
                child: TextField(
                  focusNode: _searchFocusNode,
                  controller: _searchController,
                  autofocus: false,
                  onChanged: _onSearchChanged,
                  onSubmitted: _submitSearch,
                  style: GoogleFonts.roboto(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar produtos e servicos',
                    hintStyle: GoogleFonts.roboto(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.grey,
                      size: 22,
                    ),
                    filled: true,
                    fillColor:
                        isDark ? AppTheme.blackLight : const Color(0xFFF0F2F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppTheme.blackBorder : const Color(0xFFE0E0E0),
          ),
        ),
      ),
      body: _showSuggestions
          ? _buildSearchSuggestions(isDark)
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: MarketplaceLocationActions(
                    locationLabel: _locationLabel,
                    onLocationTap: _openLocationPicker,
                    onFiltersTap: _openFilters,
                    onSavedTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FavoritesScreen(),
                      ),
                    ),
                  ),
                ),
                if (titleMatches.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Nenhum resultado encontrado para "$_query".',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.roboto(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final ad = titleMatches[index];
                          return AdCard(
                            ad: ad,
                            index: index,
                            badgeLabel: _badgeLabelForAd(ad),
                            distanceKm: _roundedDistanceKmForAd(ad),
                            onTap: () {
                              context
                                  .read<UserProvider>()
                                  .trackCategoryClick(ad.category);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdDetailScreen(ad: ad),
                                ),
                              );
                            },
                          );
                        },
                        childCount: titleMatches.length,
                      ),
                      gridDelegate: _gridDelegate(context),
                    ),
                  ),
                  if (relatedMatches.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
                        child: Text(
                          'Relacionados',
                          style: GoogleFonts.roboto(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (relatedMatches.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 100),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final ad = relatedMatches[index];
                            return AdCard(
                              ad: ad,
                              index: titleMatches.length + index,
                              badgeLabel: _badgeLabelForAd(ad),
                              distanceKm: _roundedDistanceKmForAd(ad),
                              onTap: () {
                                context
                                    .read<UserProvider>()
                                    .trackCategoryClick(ad.category);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AdDetailScreen(ad: ad),
                                  ),
                                );
                              },
                            );
                          },
                          childCount: relatedMatches.length,
                        ),
                        gridDelegate: _gridDelegate(context),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
