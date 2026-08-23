import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/points_transaction_model.dart';

abstract class PointsRepositoryBase {
  Stream<List<PointsTransactionModel>> watchUserTransactions(
    String uid, {
    int limit = 20,
  });
  Future<void> requestRedeem({
    required String uid,
    required int jumlah,
    required String deskripsi,
  });
  Future<void> reviewRedeem(
    String requestId, {
    required bool approve,
    required String reason,
  });
  Future<void> fulfillRedeem(String requestId, {String? reason});
}

class PointsRepository implements PointsRepositoryBase {
  PointsRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<PointsTransactionModel>> watchUserTransactions(
    String uid, {
    int limit = 20,
  }) {
    if (_client == null) return Stream.value(const []);
    return _client
        .from('point_ledger')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .map(
          (rows) => rows
              .take(limit)
              .map(
                (r) => PointsTransactionModel.fromMap(r['id'].toString(), {
                  'uid': r['user_id'],
                  'jenis': r['entry_type'] == 'redeem' ? 'redeem' : 'earn',
                  'jumlah': r['points'],
                  'deskripsi': r['description'],
                  'status': r['status'] == 'pending'
                      ? 'pending_redeem'
                      : 'completed',
                  'created_at': r['created_at'],
                }),
              )
              .toList(),
        );
  }

  @override
  Future<void> requestRedeem({
    required String uid,
    required int jumlah,
    required String deskripsi,
  }) async {
    await _required.rpc(
      'submit_redeem',
      params: {'p_points': jumlah, 'p_description': deskripsi},
    );
  }

  @override
  Future<void> reviewRedeem(
    String requestId, {
    required bool approve,
    required String reason,
  }) async {
    await _required.rpc(
      'approve_redeem',
      params: {
        'p_request_id': requestId,
        'p_approve': approve,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<void> fulfillRedeem(String requestId, {String? reason}) async {
    await _required.rpc(
      'fulfill_redeem',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
  }

  SupabaseClient get _required =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));
}
