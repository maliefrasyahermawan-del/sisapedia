import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/partner_actor_model.dart';

abstract class PartnerRepositoryBase {
  Stream<List<PartnerActorModel>> watchPartners();
  Future<void> requestMatch({required String partnerId, required String uid});
  Future<void> reviewProcessor(
    String processorId, {
    required bool approve,
    required String reason,
  });
  Future<void> updateProfile({
    required String processorId,
    required String displayName,
    required String processorType,
    required List<String> materials,
    required double totalCapacityKg,
    required double serviceRadiusKm,
    required double minimumPickupKg,
    required String administrativeArea,
    required String evidencePath,
    required double latitude,
    required double longitude,
  });
  Future<void> updateOperational({
    required String processorId,
    required bool active,
    required bool pickupAvailable,
    String? pickupStart,
    String? pickupEnd,
  });
}

class PartnerRepository implements PartnerRepositoryBase {
  PartnerRepository({SupabaseClient? client})
    : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<PartnerActorModel>> watchPartners() {
    if (_client == null) return Stream.value(const []);
    return _client
        .from('processor_profiles')
        .stream(primaryKey: ['id'])
        .eq('status', 'approved')
        .map(
          (rows) => rows
              .map(
                (r) => PartnerActorModel.fromMap(r['id'].toString(), {
                  'nama': r['display_name'],
                  'tipe': r['processor_type'],
                  'lat': r['latitude'],
                  'lng': r['longitude'],
                  'kapasitas_tersedia': r['available_capacity_kg'],
                  'kapasitas_total': r['total_capacity_kg'],
                  'kategori_diterima': r['materials'] ?? [],
                  'kecamatan': r['district'] ?? '',
                  'alamat': r['administrative_area'] ?? '',
                  'active': r['active'],
                  'approved': r['status'] == 'approved',
                  'pickup_available': r['pickup_available'],
                  'service_radius_km': r['service_radius_km'],
                  'minimum_pickup_kg': r['minimum_pickup_kg'],
                  'pickup_start': r['pickup_start_time'],
                  'pickup_end': r['pickup_end_time'],
                }),
              )
              .toList(),
        );
  }

  @override
  Future<void> requestMatch({
    required String partnerId,
    required String uid,
  }) async {
    final row = await _required
        .from('submissions')
        .select('id')
        .eq('source_user_id', uid)
        .inFilter('status', ['submitted', 'matching'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    final submissionId = row?['id']?.toString();
    if (submissionId == null) {
      throw StateError('Tidak ada setoran yang siap dicocokkan.');
    }
    await _required.rpc(
      'refresh_match_candidates',
      params: {'p_submission_id': submissionId},
    );
    await _required.rpc(
      'select_submission_candidate',
      params: {'p_submission_id': submissionId, 'p_processor_id': partnerId},
    );
  }

  @override
  Future<void> reviewProcessor(
    String processorId, {
    required bool approve,
    required String reason,
  }) async {
    await _required.rpc(
      'approve_processor',
      params: {
        'p_processor_id': processorId,
        'p_approve': approve,
        'p_reason': reason,
      },
    );
  }

  @override
  Future<void> updateProfile({
    required String processorId,
    required String displayName,
    required String processorType,
    required List<String> materials,
    required double totalCapacityKg,
    required double serviceRadiusKm,
    required double minimumPickupKg,
    required String administrativeArea,
    required String evidencePath,
    required double latitude,
    required double longitude,
  }) async {
    var uploadedEvidence = evidencePath;
    if (!evidencePath.startsWith('preview://')) {
      final fileName = evidencePath.split(RegExp(r'[/\\]')).last;
      uploadedEvidence = '${_required.auth.currentUser!.id}/$fileName';
      await _required.storage
          .from('processor-evidence')
          .upload(
            uploadedEvidence,
            File(evidencePath),
            fileOptions: const FileOptions(upsert: true),
          );
    }
    await _required.rpc(
      'upsert_processor_application',
      params: {
        'p_display_name': displayName,
        'p_processor_type': processorType,
        'p_materials': materials,
        'p_total_capacity_kg': totalCapacityKg,
        'p_service_radius_km': serviceRadiusKm,
        'p_minimum_pickup_kg': minimumPickupKg,
        'p_administrative_area': administrativeArea,
        'p_evidence_path': uploadedEvidence,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
  }

  @override
  Future<void> updateOperational({
    required String processorId,
    required bool active,
    required bool pickupAvailable,
    String? pickupStart,
    String? pickupEnd,
  }) async {
    if (_client == null) throw StateError('Supabase belum dikonfigurasi.');
    await _client.rpc(
      'update_processor_operational',
      params: {
        'p_active': active,
        'p_pickup_available': pickupAvailable,
        'p_pickup_start': pickupStart,
        'p_pickup_end': pickupEnd,
      },
    );
  }

  SupabaseClient get _required =>
      _client ?? (throw StateError('Supabase belum dikonfigurasi.'));
}
