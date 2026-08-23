import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:sisapedia/core/preview/fake_repositories.dart';
import 'package:sisapedia/core/services/sari_gateway_service.dart';

class _Client extends http.BaseClient {
  _Client(this.handler);

  final Future<http.StreamedResponse> Function(
    http.BaseRequest request,
    String body,
  )
  handler;
  final requests = <Map<String, dynamic>>[];
  final requestHeaders = <Map<String, String>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().bytesToString();
    requests.add(jsonDecode(body) as Map<String, dynamic>);
    requestHeaders.add(request.headers);
    return handler(request, body);
  }
}

http.StreamedResponse _jsonResponse(
  String body, {
  int status = 200,
  String contentType = 'application/json',
}) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(body)),
    status,
    headers: {'content-type': contentType},
  );
}

OmniRouteSariGatewayService _service(
  _Client client, {
  SariGatewayService? fallback,
  String appSecret = 'test-app-secret',
}) {
  return OmniRouteSariGatewayService(
    client: client,
    appSecret: appSecret,
    baseUrl: 'https://router.test/v1/chat/completions',
    fallback: fallback ?? FakeSariGatewayService(),
  );
}

void main() {
  test('normalizes live chat wrapper and preserves full history', () async {
    final client = _Client(
      (_, _) async => _jsonResponse(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content':
                    '{"status":"success","result":"{\\"text\\":\\"Jawaban live\\"}"}',
              },
            },
          ],
        }),
      ),
    );
    final result = await _service(client).chat([
      {'role': 'user', 'content': 'Pertanyaan lama'},
      {'role': 'assistant', 'content': 'Jawaban lama'},
      {'role': 'user', 'content': 'Pertanyaan baru'},
    ]);

    expect(result, 'Jawaban live');
    final messages = client.requests.single['messages'] as List<dynamic>;
    expect(messages.length, 4); // system + all three caller messages
    expect((messages[1] as Map)['content'], 'Pertanyaan lama');
    expect((messages[2] as Map)['content'], 'Jawaban lama');
    expect((messages[3] as Map)['content'], 'Pertanyaan baru');
    final headers = client.requestHeaders.single;
    expect(headers['X-App-Secret'], 'test-app-secret');
    expect(
      headers.keys.any((key) => key.toLowerCase() == 'authorization'),
      isFalse,
    );
  });

  test('normalizes extraction and validates its schema', () async {
    final client = _Client(
      (_, _) async => _jsonResponse(
        jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'kategori': 'anorganik',
                  'subtipe': 'Botol PET',
                  'berat_kg': 2.5,
                  'confidence': .98,
                }),
              },
            },
          ],
        }),
      ),
    );
    final result = await _service(
      client,
    ).extractWaste('dua setengah kilo botol');

    expect(result.category, 'anorganik');
    expect(result.subtype, 'Botol PET');
    expect(result.weightKg, 2.5);
    expect(result.confidence, .98);
  });

  test('accumulates SSE delta content and strips markdown fences', () async {
    final sse = StringBuffer('comment: router metadata\n')
      ..writeln(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': '```json\n{"text":"'},
            },
          ],
        })}',
      )
      ..writeln(
        'data: ${jsonEncode({
          'choices': [
            {
              'delta': {'content': 'SSE live"}\n```'},
            },
          ],
        })}',
      )
      ..writeln('data: [DONE]');
    final client = _Client(
      (_, _) async =>
          _jsonResponse(sse.toString(), contentType: 'text/event-stream'),
    );
    final service = OmniRouteSariGatewayService(
      client: client,
      appSecret: 'test-app-secret',
      baseUrl: 'https://router.test/v1/chat/completions',
    );
    expect(await service.chat([]), 'SSE live');
  });

  test('returns at SSE DONE without waiting for stream EOF', () async {
    final controller = StreamController<List<int>>();
    final client = _Client((_, _) async {
      scheduleMicrotask(() {
        controller.add(
          utf8.encode(
            'data: ${jsonEncode({
              'choices': [
                {
                  'delta': {'content': '{"text":"done"}'},
                },
              ],
            })}\n',
          ),
        );
        controller.add(utf8.encode('data: [DONE]\n'));
      });
      return http.StreamedResponse(
        controller.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    });
    final service = OmniRouteSariGatewayService(
      client: client,
      appSecret: 'test-app-secret',
      baseUrl: 'https://router.test/v1/chat/completions',
    );

    expect(await service.chat([]), 'done');
    await controller.close();
  });

  test('accepts plain text chat when the model ignores JSON format', () async {
    final client = _Client(
      (_, _) async => _jsonResponse(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'Jawaban teks biasa'},
            },
          ],
        }),
      ),
    );

    expect(await _service(client).chat([]), 'Jawaban teks biasa');
  });

  test('malformed and non-2xx responses use deterministic fallback', () async {
    final malformed = _Client((_, _) async => _jsonResponse('not-json'));
    final non2xx = _Client((_, _) async => _jsonResponse('{}', status: 503));
    expect(
      await _service(malformed).chat([
        {'role': 'user', 'content': 'poin'},
      ]),
      contains('Poin Sirkular'),
    );
    expect(
      await _service(non2xx).chat([
        {'role': 'user', 'content': 'poin'},
      ]),
      contains('Poin Sirkular'),
    );
  });

  test('missing token never makes a request and uses fallback', () async {
    final client = _Client((_, _) async => _jsonResponse('{}'));
    final service = _service(client, appSecret: '');

    expect(await service.chat([]), contains('Hai! Aku Sari'));
    expect(client.requests, isEmpty);
    expect(service.isOmniRouteConfigured, isFalse);
  });
}
