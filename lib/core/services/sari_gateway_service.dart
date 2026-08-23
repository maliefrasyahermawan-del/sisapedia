import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const defaultOmniRouteBaseUrl =
    'https://counting-christine-geometry-tricks.trycloudflare.com/v1/chat/completions';
const defaultOmniRouteModel = 'antigravity/gemini-3.6-flash-high';

const _omniRouteAppSecret = String.fromEnvironment('OMNIROUTE_APP_SECRET');
const _omniRouteBaseUrl = String.fromEnvironment(
  'OMNIROUTE_BASE_URL',
  defaultValue: defaultOmniRouteBaseUrl,
);
const _omniRouteModel = String.fromEnvironment(
  'OMNIROUTE_MODEL',
  defaultValue: defaultOmniRouteModel,
);

/// Client contract for the normal Sari gateway. In normal mode this continues
/// to call the Supabase `sari-proxy` Edge Function.
class SariGatewayService {
  SariGatewayService();

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Whether the currently selected gateway is configured.
  bool get isConfigured => _client != null;

  /// This is intentionally a configuration signal, not a claim about the
  /// transport used by the most recent request.
  bool get isOmniRouteConfigured => false;

  String get configurationLabel =>
      isOmniRouteConfigured ? 'OmniRoute terkonfigurasi' : 'Fallback lokal';

  Future<String> generateInsight(String dataSummary) async {
    final response = await _invoke(
      'insight',
      'Buat insight singkat berbahasa Indonesia dari data berikut: $dataSummary',
    );
    return response['text']?.toString() ?? 'Belum ada insight baru.';
  }

  Future<String> chat(List<Map<String, String>> history) async {
    final prompt = history.isEmpty ? 'Halo' : history.last['content'] ?? 'Halo';
    final response = await _invoke('chat', prompt);
    return response['text']?.toString() ?? 'Sari sedang tidak tersedia.';
  }

  Future<Map<String, dynamic>> parseWaste(String transcript) =>
      _invoke('extract', transcript);

  Future<StructuredWasteExtraction> extractWaste(String transcript) async {
    return StructuredWasteExtraction.fromMap(await parseWaste(transcript));
  }

  Future<Map<String, dynamic>> _invoke(String operation, String prompt) async {
    final client = _client;
    if (client == null) throw StateError('Gateway Sari belum dikonfigurasi');
    final result = await client.functions.invoke(
      'sari-proxy',
      body: {'operation': operation, 'prompt': prompt},
    );
    if (result.data is! Map) throw StateError('Respons Sari tidak valid');
    return Map<String, dynamic>.from(result.data as Map);
  }
}

/// Preview-mode gateway: try the user's OpenAI-compatible OmniRoute endpoint,
/// then delegate to the deterministic local gateway for every failure mode.
class OmniRouteSariGatewayService extends SariGatewayService {
  OmniRouteSariGatewayService({
    http.Client? client,
    String? appSecret,
    String? baseUrl,
    String? model,
    SariGatewayService? fallback,
  }) : _httpClient = client ?? http.Client(),
       _appSecret = appSecret ?? _omniRouteAppSecret,
       _baseUrl = baseUrl ?? _omniRouteBaseUrl,
       _model = model ?? _omniRouteModel,
       // ignore: prefer_initializing_formals
       _fallback = fallback,
       super();

  final http.Client _httpClient;
  final String _appSecret;
  final String _baseUrl;
  final String _model;
  final SariGatewayService? _fallback;

  Uri get endpoint => Uri.parse(_baseUrl);
  String get model => _model;

  @override
  bool get isConfigured => isOmniRouteConfigured || _fallback != null;

  @override
  bool get isOmniRouteConfigured => _appSecret.trim().isNotEmpty;

  @override
  String get configurationLabel => isOmniRouteConfigured
      ? 'OmniRoute terkonfigurasi (live-first)'
      : 'OmniRoute belum dikonfigurasi · fallback lokal';

  @override
  Future<String> generateInsight(String dataSummary) async {
    return _runWithFallback(
      () async {
        final response = await _invokeOmni('insight', <Map<String, String>>[
          {
            'role': 'system',
            'content':
                'Kamu adalah Sari, asisten sirkular berbahasa Indonesia. '
                'Balas hanya JSON object dengan bentuk {"text":"..."}.',
          },
          {
            'role': 'user',
            'content':
                'Buat insight singkat berbahasa Indonesia dari data berikut: '
                '$dataSummary',
          },
        ]);
        return response['text']!.toString();
      },
      () => _fallback?.generateInsight(dataSummary),
      'Sari insight tidak tersedia',
    );
  }

  @override
  Future<String> chat(List<Map<String, String>> history) async {
    final fullHistory = history.isEmpty
        ? <Map<String, String>>[
            {'role': 'user', 'content': 'Halo'},
          ]
        : history
              .map(
                (message) => {
                  'role': message['role'] ?? 'user',
                  'content': message['content'] ?? '',
                },
              )
              .toList();
    return _runWithFallback(
      () async {
        final response = await _invokeOmni('chat', <Map<String, String>>[
          {
            'role': 'system',
            'content':
                'Kamu adalah Sari, asisten sirkular SisaPedia. '
                'Jawab ringkas, ramah, dan berbahasa Indonesia. '
                'Balas hanya JSON object dengan bentuk {"text":"..."}.',
          },
          ...fullHistory,
        ]);
        return response['text']!.toString();
      },
      () => _fallback?.chat(history),
      'Sari sedang tidak tersedia',
    );
  }

  @override
  Future<Map<String, dynamic>> parseWaste(String transcript) async {
    return _runWithFallback(
      () async {
        final response = await _invokeOmni('extract', <Map<String, String>>[
          {
            'role': 'system',
            'content':
                'Ekstrak setoran sampah. Balas hanya JSON object dengan '
                'kategori (organik atau anorganik), subtipe, berat_kg '
                '(positif), confidence (0 sampai 1), dan optional '
                'perlu_klarifikasi.',
          },
          {'role': 'user', 'content': transcript},
        ]);
        StructuredWasteExtraction.fromMap(response);
        return response;
      },
      () => _fallback?.parseWaste(transcript),
      'Hasil Sari tidak memenuhi skema',
    );
  }

  Future<T> _runWithFallback<T>(
    Future<T> Function() live,
    Future<T>? Function() fallback,
    String noFallbackMessage,
  ) async {
    try {
      return await live();
    } catch (error, stackTrace) {
      developer.log(
        'Live OmniRoute request failed; using local fallback.',
        name: 'sisapedia.sari',
        error: error,
        stackTrace: stackTrace,
      );
      final local = fallback();
      if (local != null) return local;
      throw StateError(noFallbackMessage);
    }
  }

  Future<Map<String, dynamic>> _invokeOmni(
    String operation,
    List<Map<String, String>> messages,
  ) async {
    if (!isOmniRouteConfigured) {
      throw StateError('OmniRoute app secret belum dikonfigurasi');
    }
    final request = http.Request('POST', endpoint)
      ..headers.addAll({
        'X-App-Secret': _appSecret,
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'model': _model,
        'messages': messages,
        'response_format': {'type': 'json_object'},
      });
    // The endpoint can leave an SSE socket open after [DONE]. Use send() so
    // the stream can be cancelled immediately instead of waiting for EOF.
    final response = await _httpClient
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('OmniRoute HTTP ${response.statusCode}');
    }

    final completion = await _readCompletion(response);
    if (completion.isSse) {
      return _normaliseContent(operation, completion.body);
    }
    final decoded = jsonDecode(completion.body);
    if (decoded is! Map) {
      throw const FormatException('Respons OmniRoute invalid');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      throw const FormatException('Respons OmniRoute tidak memiliki choices');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map || message['content'] == null) {
      throw const FormatException('Respons OmniRoute tidak memiliki content');
    }
    return _normaliseContent(operation, message['content']);
  }

  Future<_CompletionBody> _readCompletion(
    http.StreamedResponse response,
  ) async {
    final isSse = (response.headers['content-type'] ?? '').contains(
      'text/event-stream',
    );
    if (!isSse) {
      return _CompletionBody(
        isSse: false,
        body: utf8.decode(await response.stream.toBytes()),
      );
    }
    final content = StringBuffer();
    final done = Completer<String>();
    StreamSubscription<String>? subscription;
    var finished = false;

    void finish([Object? error, StackTrace? stackTrace]) {
      if (finished) return;
      finished = true;
      unawaited(subscription?.cancel());
      if (error != null) {
        done.completeError(error, stackTrace);
      } else if (content.isEmpty) {
        done.completeError(
          const FormatException('SSE OmniRoute tidak memiliki content'),
        );
      } else {
        done.complete(content.toString());
      }
    }

    subscription = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final trimmed = line.trim();
            if (!trimmed.startsWith('data:')) return;
            final payload = trimmed.substring('data:'.length).trim();
            if (payload == '[DONE]') {
              finish();
              return;
            }
            try {
              final chunk = jsonDecode(payload);
              if (chunk is! Map) return;
              final choices = chunk['choices'];
              if (choices is! List ||
                  choices.isEmpty ||
                  choices.first is! Map) {
                return;
              }
              final choice = choices.first as Map;
              final message = choice['message'];
              final delta = choice['delta'];
              final fragment = message is Map
                  ? message['content']
                  : delta is Map
                  ? delta['content']
                  : null;
              if (fragment is String) content.write(fragment);
            } on FormatException {
              // Ignore comments and malformed SSE metadata lines; a missing or
              // malformed completion is rejected below and uses the local fallback.
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            finish(error, stackTrace);
          },
          onDone: finish,
        );

    final body = await done.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () async {
        await subscription?.cancel();
        throw TimeoutException('OmniRoute response timed out');
      },
    );
    return _CompletionBody(isSse: true, body: body);
  }

  Map<String, dynamic> _normaliseContent(String operation, dynamic content) {
    dynamic value = content;
    if (value is String) {
      final cleaned = _stripCodeFence(value);
      try {
        value = jsonDecode(cleaned);
      } on FormatException {
        if (operation != 'extract' && cleaned.trim().isNotEmpty) {
          return {'text': cleaned.trim()};
        }
        rethrow;
      }
    }
    if (value is! Map) {
      if (operation != 'extract' &&
          value is String &&
          value.trim().isNotEmpty) {
        return {'text': value.trim()};
      }
      throw const FormatException('Konten OmniRoute bukan JSON object');
    }
    final map = Map<String, dynamic>.from(value);
    if (operation != 'extract' &&
        map['text'] == null &&
        map['message'] is String &&
        (map['message'] as String).trim().isNotEmpty) {
      return {'text': (map['message'] as String).trim()};
    }
    if (map['status']?.toString().toLowerCase() == 'success' &&
        map.containsKey('result')) {
      return _normaliseResult(operation, map['result']);
    }
    return _normaliseResult(operation, map);
  }

  Map<String, dynamic> _normaliseResult(String operation, dynamic result) {
    dynamic value = result;
    if (value is String) {
      try {
        value = jsonDecode(_stripCodeFence(value));
      } catch (_) {
        if (operation != 'extract' && value.trim().isNotEmpty) {
          return {'text': value.trim()};
        }
        throw const FormatException('Result OmniRoute bukan JSON');
      }
    }
    if (value is! Map) {
      throw const FormatException('Result OmniRoute bukan object');
    }
    final map = Map<String, dynamic>.from(value);
    if (operation == 'extract') {
      StructuredWasteExtraction.fromMap(map);
    } else if (map['text']?.toString().trim().isEmpty ?? true) {
      throw const FormatException('Respons Sari tidak memiliki text');
    }
    return map;
  }

  String _stripCodeFence(String value) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('```')) return trimmed;
    final firstLine = trimmed.indexOf('\n');
    if (firstLine < 0) return trimmed;
    var unfenced = trimmed.substring(firstLine + 1).trim();
    if (unfenced.endsWith('```')) {
      unfenced = unfenced.substring(0, unfenced.length - 3).trim();
    }
    return unfenced;
  }
}

class _CompletionBody {
  const _CompletionBody({required this.isSse, required this.body});

  final bool isSse;
  final String body;
}

class HttpException implements Exception {
  const HttpException(this.message);
  final String message;

  @override
  String toString() => message;
}

class StructuredWasteExtraction {
  const StructuredWasteExtraction({
    required this.category,
    required this.subtype,
    required this.weightKg,
    required this.confidence,
    required this.needsClarification,
  });
  final String category;
  final String subtype;
  final double weightKg;
  final double confidence;
  final bool needsClarification;

  factory StructuredWasteExtraction.fromMap(Map<String, dynamic> value) {
    final weight = (value['berat_kg'] as num?)?.toDouble() ?? 0;
    final confidence = (value['confidence'] as num?)?.toDouble() ?? 0;
    final category = value['kategori']?.toString() ?? '';
    final subtype = value['subtipe']?.toString().trim() ?? '';
    if (!{'organik', 'anorganik'}.contains(category) ||
        subtype.isEmpty ||
        weight <= 0 ||
        confidence < 0 ||
        confidence > 1) {
      throw const FormatException('Hasil Sari tidak memenuhi skema');
    }
    return StructuredWasteExtraction(
      category: category,
      subtype: subtype,
      weightKg: weight,
      confidence: confidence,
      needsClarification: value['perlu_klarifikasi'] == true || confidence < .7,
    );
  }
}
