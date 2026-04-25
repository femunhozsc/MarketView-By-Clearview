import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/ad_model.dart';
import 'firestore_service.dart';

class ExternalMarketPriceService {
  ExternalMarketPriceService({http.Client? client})
      : _client = client ?? http.Client();

  static const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _geminiModel = 'gemini-2.5-flash';

  final http.Client _client;

  Future<AdPriceSuggestion?> suggestPrice({
    required String title,
    required String category,
    String? categoryType,
    List<AdAttribute> customAttributes = const [],
    List<String> searchTerms = const [],
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    int? km,
  }) async {
    final normalizedCategory = AdModel.normalizeValue(category);
    if (normalizedCategory == 'veiculos' &&
        vehicleBrand != null &&
        vehicleBrand.trim().isNotEmpty &&
        vehicleModel != null &&
        vehicleModel.trim().isNotEmpty &&
        vehicleYear != null) {
      final fipe = await _suggestFromFipe(
        categoryType: categoryType,
        vehicleBrand: vehicleBrand,
        vehicleModel: vehicleModel,
        vehicleYear: vehicleYear,
        km: km,
      );
      if (fipe != null) return fipe;
    }

    final mercadoLivre = await _suggestFromMercadoLivre(
      title: title,
      customAttributes: customAttributes,
      searchTerms: searchTerms,
    );
    if (mercadoLivre != null) return mercadoLivre;

    return _suggestFromGroundedWeb(
      title: title,
      category: category,
      categoryType: categoryType,
      customAttributes: customAttributes,
      searchTerms: searchTerms,
    );
  }

  Future<AdPriceSuggestion?> _suggestFromFipe({
    String? categoryType,
    required String vehicleBrand,
    required String vehicleModel,
    required int vehicleYear,
    int? km,
  }) async {
    final vehicleType = _resolveFipeVehicleType(categoryType);
    final brandsUri = Uri.parse(
      'https://parallelum.com.br/fipe/api/v2/$vehicleType/brands',
    );
    final brandsResponse = await _client.get(brandsUri);
    if (brandsResponse.statusCode != 200) return null;
    final brands = (jsonDecode(brandsResponse.body) as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final brand = _bestMatchByName(brands, vehicleBrand);
    if (brand == null) return null;

    final modelsUri = Uri.parse(
      'https://parallelum.com.br/fipe/api/v2/$vehicleType/brands/${brand['code']}/models',
    );
    final modelsResponse = await _client.get(modelsUri);
    if (modelsResponse.statusCode != 200) return null;
    final models = (jsonDecode(modelsResponse.body) as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final model = _bestMatchByName(models, vehicleModel);
    if (model == null) return null;

    final yearsUri = Uri.parse(
      'https://parallelum.com.br/fipe/api/v2/$vehicleType/brands/${brand['code']}/models/${model['code']}/years',
    );
    final yearsResponse = await _client.get(yearsUri);
    if (yearsResponse.statusCode != 200) return null;
    final years = (jsonDecode(yearsResponse.body) as List<dynamic>)
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final year = _bestYearMatch(years, vehicleYear);
    if (year == null) return null;

    final priceUri = Uri.parse(
      'https://parallelum.com.br/fipe/api/v2/$vehicleType/brands/${brand['code']}/models/${model['code']}/years/${year['code']}',
    );
    final priceResponse = await _client.get(priceUri);
    if (priceResponse.statusCode != 200) return null;
    final payload = Map<String, dynamic>.from(
      jsonDecode(priceResponse.body) as Map,
    );
    final fipePrice = _parseBrl(payload['price']?.toString() ?? '');
    if (fipePrice == null || fipePrice <= 0) return null;

    var minFactor = 0.9;
    var maxFactor = 1.05;
    if (km != null) {
      if (km <= 30000) {
        minFactor = 0.94;
        maxFactor = 1.08;
      } else if (km >= 120000) {
        minFactor = 0.84;
        maxFactor = 1.0;
      }
    }

    final reference = payload['referenceMonth']?.toString().trim();
    return AdPriceSuggestion(
      idealPrice: _roundPrice(fipePrice),
      minPrice: _roundPrice(fipePrice * minFactor),
      maxPrice: _roundPrice(fipePrice * maxFactor),
      sampleSize: 1,
      confidence: 'boa',
      usedLocalMatches: false,
      sourceLabel: 'FIPE',
      note: reference == null || reference.isEmpty
          ? 'Baseado na tabela FIPE'
          : 'Baseado na tabela FIPE de $reference',
    );
  }

  Future<AdPriceSuggestion?> _suggestFromGroundedWeb({
    required String title,
    required String category,
    String? categoryType,
    required List<AdAttribute> customAttributes,
    required List<String> searchTerms,
  }) async {
    if (_geminiApiKey.isEmpty) return null;

    final prompt = [
      'Voce pesquisa preco de mercado no Brasil para anuncios de marketplace.',
      'Use busca na web.',
      'Identifique o produto exato e ignore variantes diferentes.',
      'Nao misture modelos distantes. Exemplo: iPhone XR nao pode contaminar iPhone 14 Pro Max.',
      'Priorize Brasil e contexto de venda de marketplace.',
      'Considere especificacoes informadas.',
      'Retorne apenas JSON.',
      '',
      'Produto: $title',
      if (searchTerms.isNotEmpty)
        'Termos extras de busca: ${jsonEncode(searchTerms.take(5).toList())}',
      'Categoria: $category',
      'Tipo: ${categoryType ?? ''}',
      'Especificacoes: ${jsonEncode({
            for (final item in customAttributes) item.label: item.value
          })}',
      '',
      'Formato obrigatorio:',
      jsonEncode({
        'precoMinimo': 0,
        'precoIdeal': 0,
        'precoMaximo': 0,
        'confianca': 'baixa|media|boa',
        'resumo': 'string curta',
      }),
    ].join('\n');

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_geminiModel:generateContent',
      {'key': _geminiApiKey},
    );

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tools': [
          {'google_search': {}},
        ],
        'generationConfig': {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
        },
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': prompt},
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = payload['candidates'] as List<dynamic>? ?? const [];
    final content = candidates.isNotEmpty
        ? candidates.first['content'] as Map<String, dynamic>?
        : null;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final text = parts.isNotEmpty ? parts.first['text'] as String? : null;
    if (text == null || text.trim().isEmpty) return null;

    final data = _parseJsonObject(text);
    final minPrice = (data['precoMinimo'] as num?)?.toDouble();
    final idealPrice = (data['precoIdeal'] as num?)?.toDouble();
    final maxPrice = (data['precoMaximo'] as num?)?.toDouble();
    if (minPrice == null || idealPrice == null || maxPrice == null) return null;
    if (idealPrice <= 0 || maxPrice <= 0) return null;

    return AdPriceSuggestion(
      idealPrice: _roundPrice(idealPrice),
      minPrice: _roundPrice(math.min(minPrice, idealPrice)),
      maxPrice: _roundPrice(math.max(maxPrice, idealPrice)),
      sampleSize: 0,
      confidence: (data['confianca'] as String? ?? 'media').trim(),
      usedLocalMatches: false,
      sourceLabel: 'Web',
      note: (data['resumo'] as String?)?.trim().isNotEmpty == true
          ? (data['resumo'] as String).trim()
          : 'Baseado em busca externa na web',
    );
  }

  Future<AdPriceSuggestion?> _suggestFromMercadoLivre({
    required String title,
    required List<AdAttribute> customAttributes,
    required List<String> searchTerms,
  }) async {
    final queryCandidates = <String>{
      title,
      ...searchTerms,
      [
        title,
        ...customAttributes
            .map((item) => item.value.trim())
            .where((value) => value.isNotEmpty),
      ].join(' '),
    }.where((value) => value.trim().isNotEmpty).take(4).toList();

    final wantedTokens = _tokens([
      title,
      ...searchTerms,
      ...customAttributes
          .map((item) => item.value.trim())
          .where((value) => value.isNotEmpty),
    ].join(' '));
    final strongWantedTokens = _strongIntentTokens(wantedTokens);
    final prices = <double>[];
    final seenListings = <String>{};
    for (final query in queryCandidates) {
      final uri = Uri.https(
        'api.mercadolibre.com',
        '/sites/MLB/search',
        {
          'q': query,
          'limit': '20',
        },
      );

      final response = await _client.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        continue;
      }

      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final results = (payload['results'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      for (final item in results) {
        final price = (item['price'] as num?)?.toDouble();
        final titleText = item['title']?.toString() ?? '';
        if (price == null || price <= 0 || titleText.trim().isEmpty) continue;
        final listingKey =
            '${AdModel.normalizeValue(titleText)}|${price.toStringAsFixed(0)}';
        if (!seenListings.add(listingKey)) continue;

        final itemTokens = _tokens(titleText);
        if (_looksLikeAccessoryListing(
          title: titleText,
          wantedTokens: wantedTokens,
          itemTokens: itemTokens,
        )) {
          continue;
        }
        if (_hasConflictingModelTokens(wantedTokens, itemTokens)) continue;

        final overlap = wantedTokens.intersection(itemTokens).length;
        final strongOverlap =
            strongWantedTokens.intersection(itemTokens).length;
        final normalizedTitle = AdModel.normalizeValue(titleText);
        var score = overlap * 8 + strongOverlap * 18;
        if (normalizedTitle.contains(AdModel.normalizeValue(title))) {
          score += 24;
        }
        if (strongWantedTokens.isNotEmpty && strongOverlap == 0) {
          score -= 30;
        }
        if (score >= 32) {
          prices.add(price);
        }
      }
    }

    if (prices.length < 3) return null;
    prices.sort();
    final low = _percentile(prices, 0.2);
    final ideal = _percentile(prices, 0.5);
    final high = _percentile(prices, 0.8);

    return AdPriceSuggestion(
      idealPrice: _roundPrice(ideal),
      minPrice: _roundPrice(low),
      maxPrice: _roundPrice(high),
      sampleSize: prices.length,
      confidence: prices.length >= 8 ? 'boa' : 'media',
      usedLocalMatches: false,
      sourceLabel: 'Mercado Livre',
      note: 'Baseado em anuncios parecidos do Mercado Livre',
    );
  }

  String _resolveFipeVehicleType(String? categoryType) {
    final normalized = AdModel.normalizeValue(categoryType ?? '');
    if (normalized.contains('moto')) return 'motorcycles';
    if (normalized.contains('caminhao') || normalized.contains('onibus')) {
      return 'trucks';
    }
    return 'cars';
  }

  Map<String, dynamic>? _bestMatchByName(
    List<Map<String, dynamic>> items,
    String query,
  ) {
    final wantedTokens = _tokens(query);
    if (wantedTokens.isEmpty) return items.isEmpty ? null : items.first;

    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final item in items) {
      final name = item['name']?.toString() ?? '';
      final itemTokens = _tokens(name);
      var score = wantedTokens.intersection(itemTokens).length * 10;
      if (AdModel.normalizeValue(name)
          .contains(AdModel.normalizeValue(query))) {
        score += 18;
      }
      if (score > bestScore) {
        bestScore = score;
        best = item;
      }
    }
    return bestScore <= 0 ? null : best;
  }

  Map<String, dynamic>? _bestYearMatch(
    List<Map<String, dynamic>> items,
    int targetYear,
  ) {
    Map<String, dynamic>? exact;
    Map<String, dynamic>? nearest;
    var nearestDelta = 9999;
    for (final item in items) {
      final code = item['code']?.toString() ?? '';
      final year = int.tryParse(code.split('-').first);
      if (year == null) continue;
      if (year == targetYear) {
        exact = item;
        break;
      }
      final delta = (year - targetYear).abs();
      if (delta < nearestDelta) {
        nearestDelta = delta;
        nearest = item;
      }
    }
    return exact ?? nearest;
  }

  Set<String> _tokens(String value) {
    return AdModel.normalizeValue(value)
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .map((item) => item.trim())
        .where((item) => item.length >= 2)
        .toSet();
  }

  Set<String> _strongIntentTokens(Set<String> tokens) {
    const strongKeywords = {
      'pro',
      'max',
      'plus',
      'mini',
      'ultra',
      'turbo',
      'xr',
      'xs',
      'fe',
      'ssd',
      'ram',
      'gb',
      'tb',
    };
    return tokens.where((token) {
      return RegExp(r'\d').hasMatch(token) || strongKeywords.contains(token);
    }).toSet();
  }

  bool _hasConflictingModelTokens(
      Set<String> wantedTokens, Set<String> itemTokens) {
    final wantedStrong = _strongIntentTokens(wantedTokens);
    if (wantedStrong.isEmpty) return false;
    return wantedStrong.intersection(itemTokens).isEmpty;
  }

  bool _looksLikeAccessoryListing({
    required String title,
    required Set<String> wantedTokens,
    required Set<String> itemTokens,
  }) {
    const accessoryTokens = {
      'capa',
      'capinha',
      'pelicula',
      'carregador',
      'cabo',
      'fone',
      'fones',
      'case',
      'suporte',
      'adaptador',
      'peliculas',
      'cover',
      'estojo',
      'protecao',
      'tela',
      'frontal',
    };
    final accessoryOverlap = accessoryTokens.intersection(itemTokens).length;
    if (accessoryOverlap == 0) return false;

    final wantedStrong = _strongIntentTokens(wantedTokens);
    final coreOverlap = wantedStrong.intersection(itemTokens).length;
    if (coreOverlap == 0) return true;

    final normalizedTitle = AdModel.normalizeValue(title);
    return accessoryOverlap > 0 &&
        !normalizedTitle.contains('usado') &&
        !normalizedTitle.contains('seminovo') &&
        coreOverlap < math.max(1, wantedStrong.length ~/ 2);
  }

  double? _parseBrl(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9,]'), '').replaceAll('.', '');
    if (digits.isEmpty) return null;
    return double.tryParse(digits.replaceAll(',', '.'));
  }

  double _roundPrice(double value) {
    if (value < 100) return (value / 5).round() * 5;
    if (value < 1000) return (value / 10).round() * 10;
    if (value < 10000) return (value / 50).round() * 50;
    return (value / 100).round() * 100;
  }

  double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) return 0;
    if (sortedValues.length == 1) return sortedValues.first;
    final index = (sortedValues.length - 1) * percentile;
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return sortedValues[lower];
    final ratio = index - lower;
    return sortedValues[lower] +
        (sortedValues[upper] - sortedValues[lower]) * ratio;
  }

  Map<String, dynamic> _parseJsonObject(String text) {
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (match == null) {
        throw const FormatException('A IA nao retornou JSON.');
      }
      return jsonDecode(match.group(0)!) as Map<String, dynamic>;
    }
  }
}
