import 'dart:convert';
import 'dart:developer' as developer;

import '../models/ad_model.dart';
import 'package:http/http.dart' as http;

class AdAiDraftSuggestion {
  const AdAiDraftSuggestion({
    required this.correctedTitle,
    required this.suggestedDescription,
    required this.category,
    required this.categoryType,
    required this.specs,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleEngine,
    this.vehicleKm,
    this.vehicleColor,
    this.vehicleFuelType,
    this.vehicleOwnerCount,
    required this.vehicleOptionals,
    required this.priceSearchTerms,
    required this.confidence,
  });

  final String correctedTitle;
  final String suggestedDescription;
  final String category;
  final String categoryType;
  final Map<String, String> specs;
  final String? vehicleBrand;
  final String? vehicleModel;
  final int? vehicleYear;
  final String? vehicleEngine;
  final int? vehicleKm;
  final String? vehicleColor;
  final String? vehicleFuelType;
  final int? vehicleOwnerCount;
  final List<String> vehicleOptionals;
  final List<String> priceSearchTerms;
  final double confidence;

  factory AdAiDraftSuggestion.fromMap(Map<String, dynamic> data) {
    return AdAiDraftSuggestion(
      correctedTitle: (data['tituloCorrigido'] as String? ?? '').trim(),
      suggestedDescription: (data['descricaoSugerida'] as String? ?? '').trim(),
      category: (data['categoria'] as String? ?? '').trim(),
      categoryType: (data['tipo'] as String? ?? '').trim(),
      specs: AdAiService._stringMap(data['especificacoes']),
      vehicleBrand: (data['vehicleBrand'] as String?)?.trim(),
      vehicleModel: (data['vehicleModel'] as String?)?.trim(),
      vehicleYear: AdAiService._nullableInt(data['vehicleYear']),
      vehicleEngine: (data['vehicleEngine'] as String?)?.trim(),
      vehicleKm: AdAiService._nullableInt(data['vehicleKm']),
      vehicleColor: (data['vehicleColor'] as String?)?.trim(),
      vehicleFuelType: (data['vehicleFuelType'] as String?)?.trim(),
      vehicleOwnerCount: AdAiService._nullableInt(data['vehicleOwnerCount']),
      vehicleOptionals: AdAiService._stringList(data['vehicleOptionals']),
      priceSearchTerms: (data['termosBuscaPreco'] as List<dynamic>? ?? [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      confidence: (data['confianca'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AdAiService {
  AdAiService({http.Client? client}) : _client = client ?? http.Client();

  static const _apiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const _model = 'gemini-2.5-flash';
  static bool get isConfigured => _apiKey.isNotEmpty;

  final http.Client _client;

  Future<AdAiDraftSuggestion> suggestDraft({
    required String title,
    String description = '',
    required String listingTypeLabel,
    required List<String> categories,
    required Map<String, List<String>> categoryTypesByCategory,
    required Map<String, Map<String, String>> specFieldsByType,
    List<String> vehicleColors = const [],
    List<String> vehicleFuelTypes = const [],
    List<String> vehicleOptionals = const [],
  }) async {
    if (_apiKey.isEmpty) {
      throw const FormatException('GEMINI_API_KEY nao foi configurada.');
    }

    developer.log(
      'GEMINI_API_KEY recebida no app (${_apiKey.length} caracteres).',
      name: 'MarketView IA',
    );

    final prompt = [
      'Voce ajuda vendedores brasileiros a criar anuncios de marketplace.',
      'Responda somente JSON valido, sem markdown.',
      'Nao invente detalhes que o usuario nao informou.',
      'Regra mais importante para titulo: apenas corrija marca, maiusculas, acentos e ordem das palavras.',
      'Nao adicione palavras que o usuario nao digitou no titulo, como smartphone, celular, seminovo, impecavel, original ou similares.',
      'Excecao: em veiculos, pode adicionar a marca no titulo quando o modelo identificar a marca com alta confianca, como Civic -> Honda Civic.',
      'Exemplo: "14 pro max iphone" deve virar "iPhone 14 Pro Max".',
      'Exemplo: "iphone 14 pro max 256gb" deve virar "iPhone 14 Pro Max 256GB".',
      'A descricao pode usar configuracoes claras presentes no titulo, como 256GB, 128GB, cor, modelo, ano ou tamanho.',
      'Crie uma descricao curta, honesta e vendavel, com no maximo 300 caracteres.',
      'Escolha apenas uma categoria da lista fornecida.',
      'Escolha o tipo mais adequado dentro da categoria escolhida quando existir.',
      'Preencha especificacoes somente se a informacao estiver clara no titulo ou na descricao.',
      'Use apenas ids de especificacoes fornecidos em "Campos de especificacao".',
      'Para produtos e servicos, extraia tambem dados tecnicos para os campos de especificacao quando estiverem claros, como armazenamento, memoria RAM, processador, estado, experiencia, regiao, disponibilidade, modalidade ou beneficios.',
      'Se for veiculo e essas informacoes estiverem claras no titulo ou na descricao, extraia marca, modelo, ano, motorizacao, quilometragem, cor, combustivel, numero de proprietarios e opcionais.',
      'Pode inferir a marca a partir do modelo do veiculo quando isso for confiavel, por exemplo Civic -> Honda, Corolla -> Toyota.',
      'Para cor, combustivel e opcionais, use apenas valores da lista permitida.',
      '',
      'Titulo digitado: $title',
      'Descricao digitada: $description',
      'Formato do anuncio: $listingTypeLabel',
      'Categorias permitidas: ${jsonEncode(categories)}',
      'Tipos por categoria: ${jsonEncode(categoryTypesByCategory)}',
      'Campos de especificacao: ${jsonEncode(specFieldsByType)}',
      'Cores de veiculo permitidas: ${jsonEncode(vehicleColors)}',
      'Combustiveis permitidos: ${jsonEncode(vehicleFuelTypes)}',
      'Opcionais permitidos: ${jsonEncode(vehicleOptionals)}',
      '',
      'Formato obrigatorio:',
      jsonEncode({
        'tituloCorrigido': 'string',
        'descricaoSugerida': 'string',
        'categoria': 'string',
        'tipo': 'string',
        'especificacoes': {'id_do_campo': 'valor'},
        'vehicleBrand': 'string opcional',
        'vehicleModel': 'string opcional',
        'vehicleYear': 0,
        'vehicleEngine': 'string opcional',
        'vehicleKm': 0,
        'vehicleColor': 'string opcional',
        'vehicleFuelType': 'string opcional',
        'vehicleOwnerCount': 0,
        'vehicleOptionals': ['string'],
        'termosBuscaPreco': ['string'],
        'confianca': 0.0,
      }),
    ].join('\n');

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$_model:generateContent',
      {'key': _apiKey},
    );

    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'generationConfig': {
          'temperature': 0.2,
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

    developer.log(
      'Gemini respondeu HTTP ${response.statusCode}.',
      name: 'MarketView IA',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = response.body.length > 500
          ? '${response.body.substring(0, 500)}...'
          : response.body;
      throw StateError(
        'Falha ao chamar Gemini: ${response.statusCode}. Resposta: $body',
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = payload['candidates'] as List<dynamic>? ?? const [];
    final content = candidates.isNotEmpty
        ? candidates.first['content'] as Map<String, dynamic>?
        : null;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    final text = parts.isNotEmpty ? parts.first['text'] as String? : null;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Gemini nao retornou sugestao.');
    }

    return AdAiDraftSuggestion.fromMap(_parseJsonObject(text));
  }

  static String displayTypeLabel(String type) {
    return type == AdModel.serviceType ? 'Servico' : 'Produto';
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, item) => MapEntry(
        key.toString().trim(),
        item.toString().trim(),
      ),
    )..removeWhere((key, item) => key.isEmpty || item.isEmpty);
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int? _nullableInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isEmpty) return null;
      return int.tryParse(digits);
    }
    return null;
  }

  static Map<String, dynamic> _parseJsonObject(String text) {
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
