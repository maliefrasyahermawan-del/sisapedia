import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/article_model.dart';
import '../models/movement_event_model.dart';

abstract class ContentRepositoryBase {
  Stream<List<ArticleModel>> watchArticles();
  Stream<List<MovementEventModel>> watchMovementEvents();
  Future<void> joinEvent({required String eventId, required String uid});
  Future<String> createDraft({
    required String kind,
    required String title,
    required String body,
    DateTime? scheduledAt,
    String? location,
  });
  Future<void> updateDraft({
    required String id,
    required String title,
    required String body,
  });
  Future<void> submitDraft(String id);
  Future<void> moderateDraft(
    String id, {
    required bool approve,
    required String reason,
  });
}

class ContentRepository implements ContentRepositoryBase {
  ContentRepository({SupabaseClient? client, this.rpcInvoker})
    : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  final Future<dynamic> Function(String, Map<String, dynamic>)? rpcInvoker;
  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<ArticleModel>> watchArticles() {
    if (_client == null) return Stream.value(const []);
    return _client
        .from('content')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .map(
          (rows) => rows
              .map(
                (r) => ArticleModel.fromMap(r['id'].toString(), {
                  'title': r['title'],
                  'summary': r['summary'],
                  'content': r['body'],
                  'read_time_minutes': r['read_time_minutes'],
                }),
              )
              .toList(),
        );
  }

  @override
  Stream<List<MovementEventModel>> watchMovementEvents() {
    if (_client == null) return Stream.value(const []);
    return _client
        .from('events')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .map(
          (rows) => rows
              .map((r) => MovementEventModel.fromMap(r['id'].toString(), r))
              .toList(),
        );
  }

  @override
  Future<void> joinEvent({required String eventId, required String uid}) async {
    await _required.rpc('join_event', params: {'p_event_id': eventId});
  }

  @override
  Future<String> createDraft({
    required String kind,
    required String title,
    required String body,
    DateTime? scheduledAt,
    String? location,
  }) async {
    final params = <String, dynamic>{
      'p_kind': kind,
      'p_title': title,
      'p_body': body,
    };
    // The five-argument RPC is used for both kinds. Sending explicit nulls
    // avoids PostgREST overload ambiguity for articles.
    params['p_event_at'] = scheduledAt?.toUtc().toIso8601String();
    params['p_event_location'] = location;
    final result = await _rpc('create_content_draft', params);
    final id = result?.toString();
    if (id == null || id.isEmpty || id == 'null') {
      throw StateError('ID draft tidak dikembalikan.');
    }
    return id;
  }

  @override
  Future<void> updateDraft({
    required String id,
    required String title,
    required String body,
  }) => _required.rpc(
    'update_content_draft',
    params: {'p_id': id, 'p_title': title, 'p_body': body},
  );

  @override
  Future<void> submitDraft(String id) =>
      _required.rpc('submit_content_draft', params: {'p_id': id});

  @override
  Future<void> moderateDraft(
    String id, {
    required bool approve,
    required String reason,
  }) => _required.rpc(
    'moderate_content',
    params: {'p_id': id, 'p_approve': approve, 'p_reason': reason},
  );

  SupabaseClient get _required =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));

  Future<dynamic> _rpc(String function, Map<String, dynamic> params) {
    final invoke = rpcInvoker;
    if (invoke != null) return invoke(function, params);
    return _required.rpc(function, params: params);
  }
}
