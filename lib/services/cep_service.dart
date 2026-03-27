import 'dart:convert';
import 'package:http/http.dart' as http;

class CepService {
  // ViaCEP — API gratuita, sem necessidade de API key
  static const String _baseUrl = 'https://viacep.com.br/ws';

  Future<CepResult?> fetchAddress(String cep) async {
    // Remove máscara, deixa só números
    final cleanCep = cep.replaceAll(RegExp(r'\D'), '');
    if (cleanCep.length != 8) return null;

    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/$cleanCep/json/'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data.containsKey('erro')) return null;

      return CepResult(
        cep: data['cep'] ?? '',
        street: data['logradouro'] ?? '',
        neighborhood: data['bairro'] ?? '',
        city: data['localidade'] ?? '',
        state: data['uf'] ?? '',
        country: 'Brasil',
      );
    } catch (_) {
      return null;
    }
  }

  // Converte cidade/estado em coordenadas usando Nominatim (OpenStreetMap) — gratuito
  Future<LatLngResult?> geocode(String address) async {
    try {
      final encoded = Uri.encodeComponent(address);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=1';
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'MarketView/1.0'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as List;
      if (data.isEmpty) return null;

      return LatLngResult(
        lat: double.parse(data[0]['lat']),
        lng: double.parse(data[0]['lon']),
      );
    } catch (_) {
      return null;
    }
  }
}

class CepResult {
  final String cep;
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final String country;

  CepResult({
    required this.cep,
    required this.street,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.country,
  });
}

class LatLngResult {
  final double lat;
  final double lng;
  LatLngResult({required this.lat, required this.lng});
}