import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../data/models/waste_detection_result.dart';

/// Thin client for Gemini's vision API, used by "Setor Cerdas" Mode Foto to
/// detect waste category/material from a photo. Never asked to guess a
/// weight in kg — that stays a manual, user-confirmed field (see
/// WasteDetectionResult's doc comment).
///
/// Supports up to 3 API keys (GEMINI_API_KEY_1/2/3 in .env) with simple
/// sequential fallback: if a key hits a rate limit/quota error (HTTP 429),
/// the next configured key is tried before giving up.
class GeminiVisionService {
  static const _model = 'gemini-2.0-flash';
  static const _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  List<String> get _apiKeys => [
        dotenv.maybeGet('GEMINI_API_KEY_1'),
        dotenv.maybeGet('GEMINI_API_KEY_2'),
        dotenv.maybeGet('GEMINI_API_KEY_3'),
      ].whereType<String>().where((k) => k.trim().isNotEmpty).toList();

  bool get isConfigured => _apiKeys.isNotEmpty;

  static const _prompt = '''
Kamu menganalisis foto satu jenis sampah untuk aplikasi pengelolaan sampah SisaPedia.
Balas HANYA dengan JSON valid (tanpa markdown, tanpa penjelasan tambahan), persis format ini:
{
  "kategori": "organik" atau "anorganik",
  "jenis_material": "contoh: plastik / logam / kertas / sisa makanan / kaca",
  "sub_jenis": "deskripsi lebih spesifik, contoh: botol plastik PET",
  "estimasi_jumlah": jumlah item kalau bisa dihitung dari foto (angka), atau null kalau tidak relevan/tidak jelas,
  "confidence": "tinggi", "sedang", atau "rendah"
}
JANGAN mencantumkan perkiraan berat dalam kg sama sekali, itu bukan bagian dari format ini.
''';

  /// Analyzes [imageBytes] (raw photo bytes, any common format) and returns
  /// the detected waste category/material. Throws a [StateError] if no key
  /// is configured, or an [Exception] with a user-facing message if every
  /// configured key fails.
  Future<WasteDetectionResult> analyze(List<int> imageBytes) async {
    final keys = _apiKeys;
    if (keys.isEmpty) {
      throw StateError(
        'Belum ada GEMINI_API_KEY_1/2/3 yang diatur di .env',
      );
    }

    final base64Image = base64Encode(imageBytes);
    Object? lastError;

    for (var i = 0; i < keys.length; i++) {
      try {
        final response = await http.post(
          Uri.parse('$_endpoint?key=${keys[i]}'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': _prompt},
                  {
                    'inline_data': {
                      'mime_type': 'image/jpeg',
                      'data': base64Image,
                    },
                  },
                ],
              },
            ],
            'generationConfig': {
              'temperature': 0.2,
              'responseMimeType': 'application/json',
            },
          }),
        );

        if (response.statusCode == 429) {
          // Rate limit or quota exhausted on this key — try the next one.
          lastError = Exception(
            'Key Gemini #${i + 1} kena rate limit/quota habis.',
          );
          continue;
        }

        if (response.statusCode != 200) {
          throw Exception(
            'Gemini API error ${response.statusCode}: ${response.body}',
          );
        }

        return _parseResponse(response.body);
      } catch (e) {
        lastError = e;
        // Non-429 failures (network error, parse error) also fall through
        // to the next key rather than failing immediately, since a bad key
        // or transient issue on one key shouldn't block the whole feature.
        continue;
      }
    }

    throw Exception(
      'Semua key Gemini gagal dipakai. ${lastError ?? ''}'.trim(),
    );
  }

  WasteDetectionResult _parseResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
      final candidates = decoded['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('Gemini tidak mengembalikan hasil deteksi.');
      }
      final content = candidates.first['content'] as Map<String, dynamic>;
      final parts = content['parts'] as List;
      final text = (parts.first['text'] as String? ?? '').trim();
      return WasteDetectionResult.fromJson(_decodeJsonLenient(text));
    } on FormatException {
      throw Exception('Gagal membaca hasil deteksi Gemini (format tidak sesuai).');
    }
  }

  /// Strips a ```json / ``` markdown code fence if present before decoding.
  Map<String, dynamic> _decodeJsonLenient(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3);
      }
      text = text.trim();
    }
    return jsonDecode(text) as Map<String, dynamic>;
  }
}
