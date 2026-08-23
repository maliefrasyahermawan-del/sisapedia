import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/submission_model.dart';

abstract class SubmissionRepositoryBase {
  Future<String> create(SubmissionModel submission);
  Stream<List<SubmissionModel>> watchUserSubmissions(
    String uid, {
    int limit = 20,
  });
  Stream<List<SubmissionModel>> watchVerifiedSubmissions({String? uid});
  Future<void> advance(
    String id,
    SubmissionStatus status, {
    String? reason,
    double? actualWeight,
  });
  Future<void> selectCandidate(String submissionId, String processorId);
  Future<void> acceptOffer(String offerId);
  Future<void> rejectOffer(String offerId, String reason);
  Future<void> simulateOfferExpiry(String offerId);
  Future<void> setEnRoute(String submissionId);
  Future<void> cancelSubmission(String submissionId, String reason);
  Future<void> recordWeight(
    String submissionId,
    double actualWeightKg,
    String evidencePath,
  );
  Future<void> confirmWeight(String submissionId);
  Future<void> disputeWeight(String submissionId, String reason);
  Future<void> resolveDispute(
    String submissionId, {
    required bool approve,
    required String reason,
    double? correctedWeightKg,
  });
}

class SubmissionRepository implements SubmissionRepositoryBase {
  SubmissionRepository({SupabaseClient? client, this.rpcInvoker})
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
  Future<String> create(SubmissionModel submission) async {
    final result = await _rpc('create_submission', {
      'p_category': submission.kategori.name,
      'p_subtype': submission.subtipe,
      'p_description': submission.subtipe,
      'p_estimated_weight_kg': submission.beratKg,
      'p_district': submission.district ?? '',
      'p_administrative_area': submission.district ?? '',
      'p_precise_address': submission.address ?? '',
      'p_latitude': submission.latitude,
      'p_longitude': submission.longitude,
      'p_pickup_start': submission.pickupStart?.toUtc().toIso8601String(),
      'p_pickup_end': submission.pickupEnd?.toUtc().toIso8601String(),
      'p_source_photo_path': null,
    });
    final id = result?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('ID setoran tidak dikembalikan.');
    }
    final localPhoto = submission.sourcePhotoPath;
    if (localPhoto != null && localPhoto.isNotEmpty) {
      final fileName = localPhoto.split(RegExp(r'[/\\]')).last;
      final storagePath = '$id/$fileName';
      await _required.storage
          .from('source-photos')
          .upload(
            storagePath,
            File(localPhoto),
            fileOptions: const FileOptions(upsert: true),
          );
      await _required.rpc(
        'attach_source_photo',
        params: {'p_submission_id': id, 'p_storage_path': storagePath},
      );
    }
    return id;
  }

  @override
  Stream<List<SubmissionModel>> watchUserSubmissions(
    String uid, {
    int limit = 20,
  }) {
    if (_client == null) return Stream.value(const []);
    return _client
        .from('submissions')
        .stream(primaryKey: ['id'])
        .eq('source_user_id', uid)
        .map((rows) => rows.take(limit).map((r) => _fromRow(r)).toList());
  }

  @override
  Stream<List<SubmissionModel>> watchVerifiedSubmissions({String? uid}) {
    if (_client == null) return Stream.value(const []);
    return _client
        .from('submissions')
        .stream(primaryKey: ['id'])
        .map(
          (rows) => rows
              .where(
                (r) =>
                    (r['status'] == 'completed' || r['status'] == 'verified') &&
                    (uid == null || r['source_user_id'] == uid),
              )
              .map((r) => _fromRow(r))
              .toList(),
        );
  }

  SubmissionModel _fromRow(Map<String, dynamic> r) =>
      SubmissionModel.fromMap(r['id'].toString(), {
        'uid': r['source_user_id'],
        'kategori': r['material_category'],
        'subtipe': r['material_subtype'] ?? r['description'],
        'berat_kg': r['actual_weight_kg'] ?? r['estimated_weight_kg'],
        'partner_id': r['selected_processor_id'],
        'partner_name': r['processor_name'],
        'status': r['status'],
        'source': r['source'] ?? 'manual',
        'created_at': r['created_at'],
        'district': r['district'],
        'address': r['administrative_area'],
        'source_photo_path': r['source_photo_path'],
      });

  @override
  Future<void> advance(
    String id,
    SubmissionStatus status, {
    String? reason,
    double? actualWeight,
  }) async {
    await _required.rpc(
      'transition_submission',
      params: {
        'p_submission_id': id,
        'p_next_status': status == SubmissionStatus.enRoute
            ? 'en_route'
            : status.name,
        'p_reason': reason,
        'p_actual_weight_kg': actualWeight,
      },
    );
  }

  @override
  Future<void> selectCandidate(String submissionId, String processorId) async =>
      _required.rpc(
        'select_submission_candidate',
        params: {
          'p_submission_id': submissionId,
          'p_processor_id': processorId,
        },
      );
  @override
  Future<void> acceptOffer(String offerId) async =>
      _required.rpc('accept_offer', params: {'p_offer_id': offerId});
  @override
  Future<void> rejectOffer(String offerId, String reason) async => _required
      .rpc('reject_offer', params: {'p_offer_id': offerId, 'p_reason': reason});
  @override
  Future<void> simulateOfferExpiry(String offerId) async =>
      _required.rpc('expire_offer', params: {'p_offer_id': offerId});
  @override
  Future<void> setEnRoute(String submissionId) async =>
      _required.rpc('mark_en_route', params: {'p_submission_id': submissionId});
  @override
  Future<void> cancelSubmission(String submissionId, String reason) async =>
      _required.rpc(
        'cancel_submission',
        params: {'p_submission_id': submissionId, 'p_reason': reason},
      );
  @override
  Future<void> recordWeight(
    String submissionId,
    double actualWeightKg,
    String evidencePath,
  ) async {
    var path = evidencePath;
    if (!evidencePath.startsWith('preview://')) {
      final fileName = evidencePath.split(RegExp(r'[/\\]')).last;
      path = '$submissionId/$fileName';
      await _required.storage
          .from('weighing-evidence')
          .upload(
            path,
            File(evidencePath),
            fileOptions: const FileOptions(upsert: true),
          );
    }
    await _required.rpc(
      'record_weighing',
      params: {
        'p_submission_id': submissionId,
        'p_actual_weight_kg': actualWeightKg,
        'p_evidence_path': path,
      },
    );
  }

  @override
  Future<void> confirmWeight(String submissionId) async => _required.rpc(
    'confirm_weight',
    params: {'p_submission_id': submissionId},
  );
  @override
  Future<void> disputeWeight(String submissionId, String reason) async =>
      _required.rpc(
        'dispute_weight',
        params: {'p_submission_id': submissionId, 'p_reason': reason},
      );
  @override
  Future<void> resolveDispute(
    String submissionId, {
    required bool approve,
    required String reason,
    double? correctedWeightKg,
  }) async => _required.rpc(
    'resolve_dispute',
    params: {
      'p_submission_id': submissionId,
      'p_approve': approve,
      'p_reason': reason,
      'p_corrected_weight_kg': correctedWeightKg,
    },
  );

  SupabaseClient get _required =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));

  Future<dynamic> _rpc(String function, Map<String, dynamic> params) {
    final invoke = rpcInvoker;
    if (invoke != null) return invoke(function, params);
    return _required.rpc(function, params: params);
  }
}
