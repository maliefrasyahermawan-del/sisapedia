import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import '../../data/models/submission_model.dart';
import '../utils/level_utils.dart';

/// Drives the live Sumber<->Pengolah exchange state machine
/// ([SubmissionFlowStatus]) on top of Firestore. Deliberately separate from
/// [SubmissionRepositoryBase] — this only makes sense with a real backend
/// (two devices need to see the same doc), so it has no offline/Fake
/// counterpart; screens that use it must be reached only when
/// `!kPreviewMode`.
class SubmissionFlowService {
  SubmissionFlowService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _submissions =>
      _db.collection('submissions');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');

  /// Minimal residual points if Sumber chooses to leave the waste at
  /// Pengolah's after a verification mismatch instead of taking it back or
  /// negotiating — same "estimate, not final" spirit as the rest of the
  /// points system (see `level_utils.dart`).
  static const _poinMinimalMultiplier = 0.2;
  static const _poinMinimalFloor = 5;

  /// New submissions waiting for any Pengolah to accept — a single shared
  /// queue since this demo only has one Pengolah testing account.
  ///
  /// Deliberately a single `where` (no `orderBy`, sorted client-side
  /// instead) — combining an equality filter with `orderBy` on a different
  /// field needs a composite Firestore index that doesn't exist yet on a
  /// fresh project, which would fail at query time until someone manually
  /// creates it in the console.
  Stream<List<SubmissionModel>> watchIncomingQueue() {
    return _submissions
        .where('flow_status',
            isEqualTo: SubmissionFlowStatus.menungguKonfirmasi.name)
        .snapshots()
        .map((snap) {
      final items =
          snap.docs.map((d) => SubmissionModel.fromMap(d.id, d.data())).toList();
      items.sort((a, b) =>
          (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
      return items;
    });
  }

  /// Submissions this Pengolah has already claimed and are still in
  /// progress (accepted, in transit, or being verified).
  ///
  /// Filters `flow_status` client-side for the same composite-index reason
  /// as [watchIncomingQueue] — a single-Pengolah demo never has enough live
  /// submissions for that to matter performance-wise.
  Stream<List<SubmissionModel>> watchPengolahAktif(String pengolahUid) {
    const active = {
      SubmissionFlowStatus.dikonfirmasi,
      SubmissionFlowStatus.diterimaPengolah,
      SubmissionFlowStatus.sedangDiverifikasi,
    };
    return _submissions
        .where('pengolah_uid', isEqualTo: pengolahUid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SubmissionModel.fromMap(d.id, d.data()))
            .where((s) => active.contains(s.flowStatus))
            .toList());
  }

  Future<void> confirmByPengolah({
    required String submissionId,
    required String pengolahUid,
    required String pengolahNama,
    String? pengolahTelepon,
  }) async {
    await _submissions.doc(submissionId).update({
      'flow_status': SubmissionFlowStatus.dikonfirmasi.name,
      'pengolah_uid': pengolahUid,
      'pengolah_nama': pengolahNama,
      'pengolah_telepon': pengolahTelepon,
      'waktu_dikonfirmasi': FieldValue.serverTimestamp(),
    });
    await _notifySumber(
      submissionId,
      title: 'Permintaan setor disetujui',
      body: '$pengolahNama menerima permintaan setoranmu. Cek detail '
          'kontak & langkah berikutnya di layar progress.',
      type: NotificationType.setoran,
    );
  }

  Future<void> rejectByPengolah({
    required String submissionId,
    required String pengolahNama,
  }) async {
    await _submissions.doc(submissionId).update({
      'flow_status': SubmissionFlowStatus.ditolakPengolah.name,
      'status': SubmissionStatus.rejected.name,
      'waktu_selesai': FieldValue.serverTimestamp(),
    });
    await _notifySumber(
      submissionId,
      title: 'Permintaan setor ditolak',
      body: '$pengolahNama tidak bisa menerima setoran ini. Coba ajukan ke '
          'mitra lain ya.',
      type: NotificationType.setoran,
    );
  }

  Future<void> markDiterimaPengolah(String submissionId) async {
    await _submissions.doc(submissionId).update({
      'flow_status': SubmissionFlowStatus.diterimaPengolah.name,
      'waktu_diterima_pengolah': FieldValue.serverTimestamp(),
    });
    await _notifySumber(
      submissionId,
      title: 'Sampah telah diterima Pengolah',
      body: 'Sekarang sedang diverifikasi kesesuaiannya.',
      type: NotificationType.setoran,
    );
    // Verification starts right away — Pengolah reviews on the same screen.
    await _submissions.doc(submissionId).update({
      'flow_status': SubmissionFlowStatus.sedangDiverifikasi.name,
    });
  }

  Future<void> approveVerifikasi(String submissionId) async {
    await _db.runTransaction((tx) async {
      final subRef = _submissions.doc(submissionId);
      final subSnap = await tx.get(subRef);
      final data = subSnap.data();
      if (data == null) return;
      final uid = data['uid'] as String;
      final beratKg = (data['berat_kg'] as num).toDouble();
      final poin = estimatedPoinFromKg(beratKg);
      tx.update(subRef, {
        'flow_status': SubmissionFlowStatus.disetujui.name,
        'status': SubmissionStatus.verified.name,
        'final_poin': poin,
        'qr_payload': 'SISAPEDIA-BERHASIL-DISETOR:$submissionId',
        'waktu_selesai': FieldValue.serverTimestamp(),
      });
      tx.update(_users.doc(uid), {'poin_sirkular': FieldValue.increment(poin)});
    });
    await _notifySumber(
      submissionId,
      title: 'Setoran disetujui!',
      body: 'Poin sudah masuk ke akunmu. Tunjukkan QR di layar progress '
          'sebagai bukti setor berhasil.',
      type: NotificationType.poin,
    );
  }

  /// Pengolah marks the submission as not matching what was declared.
  /// Simplified (26 Agustus 2026): this finalizes immediately with a small
  /// consolation number of points — no negotiation menu for Sumber to pick
  /// through, since the waste already physically changed hands. Reads as
  /// "not successful" (no QR), but points are still credited.
  Future<void> rejectVerifikasi({
    required String submissionId,
    required String catatan,
  }) async {
    await _db.runTransaction((tx) async {
      final subRef = _submissions.doc(submissionId);
      final subSnap = await tx.get(subRef);
      final data = subSnap.data();
      if (data == null) return;
      final uid = data['uid'] as String;
      final beratKg = (data['berat_kg'] as num).toDouble();
      final poin = ((estimatedPoinFromKg(beratKg) * _poinMinimalMultiplier)
              .round())
          .clamp(_poinMinimalFloor, 1 << 30);
      tx.update(subRef, {
        'flow_status': SubmissionFlowStatus.selesaiPoinMinimal.name,
        'status': SubmissionStatus.verified.name,
        'catatan_verifikasi': catatan,
        'final_poin': poin,
        'waktu_selesai': FieldValue.serverTimestamp(),
      });
      tx.update(_users.doc(uid), {'poin_sirkular': FieldValue.increment(poin)});
    });
    await _notifySumber(
      submissionId,
      title: 'Setor tidak berhasil',
      body: 'Pengolah menemukan ketidaksesuaian: $catatan. Sampah tetap '
          'sudah diberikan, jadi kamu tetap dapat poin sedikit.',
      type: NotificationType.setoran,
    );
  }

  Future<void> _notifySumber(
    String submissionId, {
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    final subDoc = await _submissions.doc(submissionId).get();
    final uid = subDoc.data()?['uid'] as String?;
    if (uid == null) return;
    await _notifications.add({
      'uid': uid,
      'title': title,
      'body': body,
      'type': type.name,
      'submission_id': submissionId,
      'read': false,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}

final submissionFlowServiceProvider =
    Provider<SubmissionFlowService>((ref) => SubmissionFlowService());
