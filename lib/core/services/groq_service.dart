import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thin client for Groq's OpenAI-compatible chat completions API, used to
/// generate the short "Insight AI Sari" sentences shown on the dashboard.
class GroqService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.1-8b-instant';

  String? get _apiKey => dotenv.maybeGet('GROQ_API_KEY');

  bool get isConfigured => (_apiKey ?? '').isNotEmpty;

  static const _systemPrompt =
      'Kamu adalah Sari, asisten AI di aplikasi SisaPedia yang membantu warga '
      'mengelola sampah secara sirkular. Balas HANYA dengan 1-2 kalimat insight '
      'singkat berbahasa Indonesia yang ramah dan memotivasi, berdasarkan data '
      'setoran sampah yang diberikan. Jangan pakai markdown, jangan beri salam '
      'pembuka, langsung ke insight-nya.';

  static const _chatSystemPrompt =
      'Kamu adalah Sari, asisten sirkular percakapan di aplikasi SisaPedia. '
      'Bantu warga dengan pertanyaan seputar Poin Sirkular, cara setor sampah '
      'organik/anorganik, jadwal jemput, mitra bank sampah/pengepul, dan cara '
      'kerja aplikasi. Jawab singkat (maksimal 3 kalimat), ramah, berbahasa '
      'Indonesia, tanpa markdown. Kamu bisa membantu mencatat setoran dari '
      'bahasa natural, tapi kamu TIDAK melakukan pencocokan otomatis dan '
      'TIDAK mengonfirmasi transaksi apa pun secara otomatis, itu tetap '
      'dilakukan pengguna secara manual di aplikasi. Kalau ditanya di luar '
      'topik sampah/SisaPedia, arahkan kembali dengan sopan.';

  /// General conversational chat for the Sari assistant screen. [history] is
  /// the prior turns as `{role: 'user'|'assistant', content: '...'}`, most
  /// recent last; does not include the system prompt.
  Future<String> chat(List<Map<String, String>> history) async {
    if (!isConfigured) {
      throw StateError('GROQ_API_KEY belum diatur di .env');
    }
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _chatSystemPrompt},
          ...history,
        ],
        'temperature': 0.6,
        'max_tokens': 200,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq API tidak mengembalikan hasil');
    }
    final message = choices.first['message'] as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }

  Future<String> generateInsight(String dataSummary) async {
    if (!isConfigured) {
      throw StateError('GROQ_API_KEY belum diatur di .env');
    }
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': dataSummary},
        ],
        'temperature': 0.6,
        'max_tokens': 120,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Groq API error ${response.statusCode}: ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw Exception('Groq API tidak mengembalikan hasil');
    }
    final message = choices.first['message'] as Map<String, dynamic>;
    return (message['content'] as String? ?? '').trim();
  }
}
