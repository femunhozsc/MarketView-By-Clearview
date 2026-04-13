import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../services/location_service.dart';

class LocationPickerResult {
  final double lat;
  final double lng;
  final int radiusKm;
  final String label;
  final String scope;
  final String regionKey;

  const LocationPickerResult({
    required this.lat,
    required this.lng,
    required this.radiusKm,
    required this.label,
    required this.scope,
    required this.regionKey,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLng;
  final int initialRadiusKm;
  final String initialLabel;

  const LocationPickerScreen({
    super.key,
    required this.initialLat,
    required this.initialLng,
    required this.initialRadiusKm,
    required this.initialLabel,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _RegionPreset {
  final String label;
  final String scope;
  final String regionKey;
  final LatLng center;
  final List<String> aliases;

  const _RegionPreset({
    required this.label,
    required this.scope,
    required this.regionKey,
    required this.center,
    required this.aliases,
  });
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const LatLng _campoMourao = LatLng(-24.0466, -52.3780);
  static const String _scopeCity = 'city';
  static const String _scopeState = 'state';
  static const String _scopeCountry = 'country';

  static const List<_RegionPreset> _presets = [
    _RegionPreset(
      label: 'Brasil',
      scope: _scopeCountry,
      regionKey: 'br',
      center: LatLng(-14.2350, -51.9253),
      aliases: ['brasil', 'brazil'],
    ),
    _RegionPreset(
      label: 'Parana',
      scope: _scopeState,
      regionKey: 'pr',
      center: LatLng(-24.8949, -51.5506),
      aliases: ['parana', 'pr'],
    ),
    _RegionPreset(
      label: 'Sao Paulo',
      scope: _scopeState,
      regionKey: 'sp',
      center: LatLng(-22.19, -48.79),
      aliases: ['sao paulo', 'sp'],
    ),
    _RegionPreset(
      label: 'Rio de Janeiro',
      scope: _scopeState,
      regionKey: 'rj',
      center: LatLng(-22.9068, -43.1729),
      aliases: ['rio de janeiro', 'rj'],
    ),
    _RegionPreset(
      label: 'Minas Gerais',
      scope: _scopeState,
      regionKey: 'mg',
      center: LatLng(-18.5122, -44.5550),
      aliases: ['minas gerais', 'mg'],
    ),
    _RegionPreset(
      label: 'Santa Catarina',
      scope: _scopeState,
      regionKey: 'sc',
      center: LatLng(-27.2423, -50.2189),
      aliases: ['santa catarina', 'sc'],
    ),
    _RegionPreset(
      label: 'Rio Grande do Sul',
      scope: _scopeState,
      regionKey: 'rs',
      center: LatLng(-30.0346, -51.2177),
      aliases: ['rio grande do sul', 'rs'],
    ),
    _RegionPreset(
      label: 'Bahia',
      scope: _scopeState,
      regionKey: 'ba',
      center: LatLng(-12.9714, -38.5014),
      aliases: ['bahia', 'ba'],
    ),
    _RegionPreset(
      label: 'Goias',
      scope: _scopeState,
      regionKey: 'go',
      center: LatLng(-16.6869, -49.2648),
      aliases: ['goias', 'go'],
    ),
    _RegionPreset(
      label: 'Distrito Federal',
      scope: _scopeState,
      regionKey: 'df',
      center: LatLng(-15.7939, -47.8828),
      aliases: ['distrito federal', 'df', 'brasilia'],
    ),
  ];

  final MapController _mapController = MapController();
  late final TextEditingController _labelController;
  LatLng? _selectedPoint;
  late double _radiusKm;
  late double _radiusSliderValue;
  String _selectedScope = _scopeCity;
  String _selectedRegionKey = '';
  bool _loadingCurrentLocation = false;

  bool get _isRadiusLocked =>
      _selectedScope == _scopeState || _selectedScope == _scopeCountry;

  List<_RegionPreset> get _matchingPresets {
    final query = _normalize(widgetText: _labelController.text);
    if (query.isEmpty) return _presets;
    return _presets
        .where(
          (preset) => preset.aliases.any(
            (alias) => _normalize(widgetText: alias).contains(query),
          ),
        )
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _selectedPoint = LatLng(widget.initialLat, widget.initialLng);
    _radiusKm = widget.initialRadiusKm.clamp(1, 1000).toDouble();
    _radiusSliderValue = _sliderValueFromRadius(_radiusKm);
    _labelController = TextEditingController(text: widget.initialLabel);
    _selectedRegionKey = _normalize(widgetText: widget.initialLabel);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  String _normalize({required String widgetText}) {
    final lower = widgetText.trim().toLowerCase();
    return lower
        .replaceAll('ã', 'a')
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ç', 'c');
  }

  double _sliderValueFromRadius(double radiusKm) {
    if (radiusKm <= 200) {
      return ((radiusKm - 1) / 199) * 0.5;
    }
    return 0.5 + (((radiusKm - 200) / 800).clamp(0, 1) * 0.5);
  }

  double _radiusFromSliderValue(double sliderValue) {
    if (sliderValue <= 0.5) {
      return 1 + ((sliderValue / 0.5) * 199);
    }
    return 200 + (((sliderValue - 0.5) / 0.5) * 800);
  }



  Future<void> _useCurrentLocation() async {
    setState(() => _loadingCurrentLocation = true);
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Localizacao desativada'),
              content: const Text(
                'Ative a localizacao do dispositivo para usar essa funcao.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Abrir ajustes'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await Geolocator.openLocationSettings();
          }
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissao de localizacao negada.'),
            ),
          );
        }
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permissao bloqueada'),
              content: const Text(
                'A permissao de localizacao foi bloqueada. Abra as configuracoes do app para liberar.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Abrir configuracoes'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await Geolocator.openAppSettings();
          }
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      final point = LatLng(position.latitude, position.longitude);
      final cityLabel = await LocationService.reverseGeocodeCityLabel(point);
      _selectedScope = _scopeCity;
      _selectedRegionKey = _normalize(widgetText: cityLabel.split(',').first);
      _moveTo(
        point,
        label: cityLabel,
      );
    } finally {
      if (mounted) {
        setState(() => _loadingCurrentLocation = false);
      }
    }
  }

  void _moveTo(LatLng point, {String? label}) {
    setState(() {
      _selectedPoint = point;
      if (label != null) {
        _labelController.text = label;
      }
    });
    _mapController.move(point, _zoomForCurrentSelection());
  }

  double _zoomForCurrentSelection() {
    if (_selectedScope == _scopeCountry) return 4.2;
    if (_selectedScope == _scopeState) return 6.8;
    return _zoomForRadiusKm(_radiusKm);
  }

  double _zoomForRadiusKm(double radiusKm) {
    if (radiusKm <= 2) return 13.5;
    if (radiusKm <= 5) return 12.8;
    if (radiusKm <= 10) return 12.0;
    if (radiusKm <= 25) return 11.0;
    if (radiusKm <= 50) return 10.2;
    if (radiusKm <= 100) return 9.3;
    if (radiusKm <= 200) return 8.4;
    if (radiusKm <= 400) return 7.5;
    if (radiusKm <= 700) return 6.6;
    return 6.0;
  }

  _RegionPreset? _findPreset(String input) {
    final normalized = _normalize(widgetText: input);
    for (final preset in _presets) {
      if (preset.aliases.any((alias) => _normalize(widgetText: alias) == normalized)) {
        return preset;
      }
    }
    return null;
  }

  void _applyPreset(_RegionPreset preset) {
    _selectedScope = preset.scope;
    _selectedRegionKey = preset.regionKey;
    _moveTo(preset.center, label: preset.label);
  }

  void _useTypedLocationAsCity() {
    final text = _labelController.text.trim();
    _selectedScope = _scopeCity;
    _selectedRegionKey = _normalize(widgetText: text);
  }

  void _handleLabelChanged(String value) {
    setState(() {
      _selectedScope = _scopeCity;
      _selectedRegionKey = _normalize(widgetText: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final point = _selectedPoint ?? _campoMourao;
    final suggestions = _matchingPresets;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.black : AppTheme.lightBg,
      appBar: AppBar(
        title: const Text('Localizacao dos anuncios'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.blackCard : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppTheme.blackBorder : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Escolha o ponto central ou uma regiao pronta',
                      style: GoogleFonts.roboto(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Digite Brasil, um estado como Parana ou Sao Paulo, ou uma cidade. Estados e pais bloqueiam o raio; cidade libera ajuste fino.',
                      style: GoogleFonts.roboto(
                        color: isDark ? AppTheme.whiteSecondary : Colors.grey.shade700,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _labelController,
                      onChanged: _handleLabelChanged,
                      onSubmitted: (_) => _useTypedLocationAsCity(),
                      style: GoogleFonts.roboto(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Buscar local',
                        hintText: 'Brasil, Parana, Sao Paulo ou Campo Mourao',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    if (suggestions.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: suggestions.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final preset = suggestions[index];
                            return ActionChip(
                              label: Text(preset.label),
                              onPressed: () => _applyPreset(preset),
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isRadiusLocked
                                ? 'Raio bloqueado para ${_selectedScope == _scopeCountry ? 'pais' : 'estado'}'
                                : 'Raio: ${_radiusKm.round()} km',
                            style: GoogleFonts.roboto(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loadingCurrentLocation ? null : _useCurrentLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Usar localizacao'),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radiusSliderValue,
                      min: 0,
                      max: 1,
                      divisions: 1000,
                      label: '${_radiusKm.round()} km',
                      onChanged: _isRadiusLocked
                          ? null
                          : (value) {
                              final nextRadius = _radiusFromSliderValue(value);
                              setState(() {
                                _radiusSliderValue = value;
                                _radiusKm = nextRadius.clamp(1, 1000);
                              });
                              _mapController.move(point, _zoomForCurrentSelection());
                            },
                    ),
                    Row(
                      children: [
                        Text('1 km', style: GoogleFonts.roboto(color: Colors.grey)),
                        const Spacer(),
                        Text('200 km', style: GoogleFonts.roboto(color: Colors.grey)),
                        const Spacer(),
                        Text('1000 km', style: GoogleFonts.roboto(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: point,
                      initialZoom: _zoomForCurrentSelection(),
                      onTap: (_, tappedPoint) {
                        if (_isRadiusLocked) return;
                        setState(() {
                          _selectedPoint = tappedPoint;
                          _selectedScope = _scopeCity;
                          _selectedRegionKey =
                              _normalize(widgetText: _labelController.text.trim());
                          if (_labelController.text.trim().isEmpty) {
                            _labelController.text = 'Ponto selecionado';
                          }
                        });
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.clearviewdev.marketview',
                      ),
                      if (!_isRadiusLocked)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: point,
                              radius: _radiusKm * 1000,
                              useRadiusInMeter: true,
                              color: AppTheme.facebookBlue.withValues(alpha: 0.14),
                              borderColor: AppTheme.facebookBlue.withValues(alpha: 0.5),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: point,
                            width: 56,
                            height: 56,
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppTheme.facebookBlue,
                              size: 42,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final label = _labelController.text.trim().isEmpty
                        ? 'Ponto selecionado'
                        : _labelController.text.trim();
                    final preset = _findPreset(label);
                    if (preset != null) {
                      _selectedScope = preset.scope;
                      _selectedRegionKey = preset.regionKey;
                    } else {
                      _useTypedLocationAsCity();
                    }
                    Navigator.pop(
                      context,
                      LocationPickerResult(
                        lat: point.latitude,
                        lng: point.longitude,
                        radiusKm: _radiusKm.round(),
                        label: label,
                        scope: _selectedScope,
                        regionKey: _selectedRegionKey,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text('Ver anuncios'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
