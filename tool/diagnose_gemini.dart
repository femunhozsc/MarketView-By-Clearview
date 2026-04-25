import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

Future<void> main() async {
  final apiKey = Platform.environment['GEMINI_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('GEMINI_API_KEY nao existe no ambiente do terminal.');
    exitCode = 1;
    return;
  }

  stdout.writeln('GEMINI_API_KEY encontrada (${apiKey.length} caracteres).');

  final uri = Uri.https(
    'generativelanguage.googleapis.com',
    '/v1beta/models/gemini-2.5-flash:generateContent',
    {'key': apiKey},
  );

  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'text':
                  'Responda somente JSON valido: {"ok":true,"titulo":"Honda Civic 2008"}',
            },
          ],
        },
      ],
    }),
  );

  stdout.writeln('HTTP ${response.statusCode}');
  stdout.writeln(response.body);

  if (response.statusCode < 200 || response.statusCode >= 300) {
    exitCode = 1;
  }
}
