import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class LocationService {
  static Future<String> reverseGeocodeCityLabel(LatLng point) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=jsonv2'
        '&lat=${point.latitude}&lon=${point.longitude}&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'MarketView/1.0',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode != 200) {
        return 'Minha localizacao';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final address = (json['address'] as Map<String, dynamic>?) ?? const {};
      final city = (address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              address['county'])
          ?.toString()
          .trim();
      final stateCode = address['state_code']?.toString().trim().toUpperCase();
      final state = address['state']?.toString().trim();

      if (city != null && city.isNotEmpty) {
        if (stateCode != null && stateCode.isNotEmpty) {
          return '$city, $stateCode';
        }
        if (state != null && state.isNotEmpty) {
          return '$city, $state';
        }
        return city;
      }
    } catch (_) {
      // Mantem fallback amigavel.
    }
    return 'Minha localizacao';
  }
}
