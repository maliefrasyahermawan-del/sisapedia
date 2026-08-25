import 'package:cloud_firestore/cloud_firestore.dart';

enum WasteCategory { organik, anorganik }

extension WasteCategoryX on WasteCategory {
  String get label => this == WasteCategory.organik ? 'Organik' : 'Anorganik';

  static WasteCategory fromString(String value) {
    return value == 'anorganik' ? WasteCategory.anorganik : WasteCategory.organik;
  }

  String get value => name;
}

enum SubmissionStatus { pending, verified, rejected }

/// Granular state machine for the Sumber<->Pengolah live exchange flow
/// (26 Agustus 2026). Kept separate from [SubmissionStatus] (which stays
/// the coarse pending/verified/rejected used by dashboard aggregation and
/// history badges) so nothing that already reads [SubmissionStatus] needs
/// to change — [flowStatus] just gets a lot more specific in between.
enum SubmissionFlowStatus {
  /// Just submitted by Sumber, waiting for a Pengolah to accept the request.
  menungguKonfirmasi,

  /// A Pengolah accepted the request — delivery (per [DeliveryMode]) is now
  /// coordinated manually between the two parties using the contact info
  /// attached to the submission.
  dikonfirmasi,

  /// Pengolah marked the waste as physically received.
  diterimaPengolah,

  /// Pengolah is comparing the physical waste against what was declared.
  sedangDiverifikasi,

  /// Pengolah confirmed everything matches — full points awarded + QR
  /// receipt shown to Sumber.
  disetujui,

  /// Pengolah found a mismatch — this is a terminal outcome, not a request
  /// for Sumber to decide anything (simplified 26 Agustus 2026, after the
  /// original 3-way negotiation menu turned out to be more than what was
  /// wanted): a small consolation number of points is awarded automatically
  /// since the waste was already physically handed over, but the submission
  /// itself reads as "not successful" (no QR).
  selesaiPoinMinimal,

  /// Pengolah rejected the request outright, before any physical exchange —
  /// no points at all.
  ditolakPengolah,
}

extension SubmissionFlowStatusX on SubmissionFlowStatus {
  String get label {
    switch (this) {
      case SubmissionFlowStatus.menungguKonfirmasi:
        return 'Menunggu Konfirmasi Pengolah';
      case SubmissionFlowStatus.dikonfirmasi:
        return 'Disetujui Pengolah';
      case SubmissionFlowStatus.diterimaPengolah:
        return 'Sampah Diterima Pengolah';
      case SubmissionFlowStatus.sedangDiverifikasi:
        return 'Sedang Diverifikasi Pengolah';
      case SubmissionFlowStatus.disetujui:
        return 'Setoran Disetujui';
      case SubmissionFlowStatus.selesaiPoinMinimal:
        return 'Setor Tidak Berhasil (Poin Minimal)';
      case SubmissionFlowStatus.ditolakPengolah:
        return 'Ditolak Pengolah';
    }
  }

  /// Full success — points in full + QR receipt.
  bool get isSuccessOutcome => this == SubmissionFlowStatus.disetujui;

  /// Not a successful setor, but Sumber still keeps a few points since the
  /// waste already physically left their hands.
  bool get isPartialOutcome => this == SubmissionFlowStatus.selesaiPoinMinimal;

  /// No points at all.
  bool get isFailureOutcome => this == SubmissionFlowStatus.ditolakPengolah;

  bool get isTerminal => isSuccessOutcome || isPartialOutcome || isFailureOutcome;

  static SubmissionFlowStatus fromString(String? value) {
    return SubmissionFlowStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubmissionFlowStatus.menungguKonfirmasi,
    );
  }
}

extension SubmissionStatusX on SubmissionStatus {
  String get label {
    switch (this) {
      case SubmissionStatus.pending:
        return 'Menunggu';
      case SubmissionStatus.verified:
        return 'Terverifikasi';
      case SubmissionStatus.rejected:
        return 'Ditolak';
    }
  }

  static SubmissionStatus fromString(String value) {
    return SubmissionStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => SubmissionStatus.pending,
    );
  }
}

enum SubmissionSource { manual, voice, foto }

enum DeliveryMode { cod, antarLangsung, requestPengolah }

extension DeliveryModeX on DeliveryMode {
  String get label {
    switch (this) {
      case DeliveryMode.cod:
        return 'COD (Ketemu Langsung)';
      case DeliveryMode.antarLangsung:
        return 'Antar Langsung';
      case DeliveryMode.requestPengolah:
        return 'Request Pengolah Datang';
    }
  }

  static DeliveryMode? fromString(String? value) {
    if (value == null) return null;
    for (final mode in DeliveryMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}

class SubmissionModel {
  final String id;
  final String uid;

  /// Sumber's display name, denormalized at creation time so Pengolah's
  /// incoming-queue list can show who's submitting without an extra
  /// `users/{uid}` lookup per item.
  final String? namaSumber;
  final WasteCategory kategori;
  final String subtipe;
  final double beratKg;
  final String? partnerId;
  final String? partnerName;
  final SubmissionStatus status;
  final SubmissionSource source;
  final DateTime? createdAt;

  /// Photo evidence of the waste — either taken specifically as bukti
  /// (manual flow) or the same photo used for AI detection (foto flow).
  final String? fotoUrl;

  /// Pickup/delivery address, entered manually each time (the app doesn't
  /// store a saved address on the user's profile yet). Meaning depends on
  /// [deliveryMode] — pickup address, drop-off destination, or COD meeting
  /// point.
  final String? alamat;
  final DateTime? tanggalPengantaran;
  final String? waktuPengantaran;
  final String? catatan;
  final DeliveryMode? deliveryMode;

  /// Live Sumber<->Pengolah exchange state (26 Agustus 2026 feature) — see
  /// [SubmissionFlowStatus] doc comments for what each stage means.
  final SubmissionFlowStatus flowStatus;
  final String? pengolahUid;
  final String? pengolahNama;
  final String? pengolahTelepon;

  /// Pengolah's reason when marking a submission as not matching what was
  /// declared (leads straight to [SubmissionFlowStatus.selesaiPoinMinimal]).
  final String? catatanVerifikasi;

  /// Points actually awarded once the flow reaches a success outcome — null
  /// until then (the estimate shown right after submit is a *different*,
  /// purely presentational number, see `estimatedPoinFromKg()`).
  final int? finalPoin;

  /// Receipt QR payload, set once the flow reaches a success outcome.
  final String? qrPayload;

  final DateTime? waktuDikonfirmasi;
  final DateTime? waktuDiterimaPengolah;
  final DateTime? waktuSelesai;

  const SubmissionModel({
    required this.id,
    required this.uid,
    this.namaSumber,
    required this.kategori,
    required this.subtipe,
    required this.beratKg,
    this.partnerId,
    this.partnerName,
    this.status = SubmissionStatus.pending,
    this.source = SubmissionSource.manual,
    this.createdAt,
    this.fotoUrl,
    this.alamat,
    this.tanggalPengantaran,
    this.waktuPengantaran,
    this.catatan,
    this.deliveryMode,
    this.flowStatus = SubmissionFlowStatus.menungguKonfirmasi,
    this.pengolahUid,
    this.pengolahNama,
    this.pengolahTelepon,
    this.catatanVerifikasi,
    this.finalPoin,
    this.qrPayload,
    this.waktuDikonfirmasi,
    this.waktuDiterimaPengolah,
    this.waktuSelesai,
  });

  SubmissionModel copyWith({String? id}) {
    return SubmissionModel(
      id: id ?? this.id,
      uid: uid,
      namaSumber: namaSumber,
      kategori: kategori,
      subtipe: subtipe,
      beratKg: beratKg,
      partnerId: partnerId,
      partnerName: partnerName,
      status: status,
      source: source,
      createdAt: createdAt,
      fotoUrl: fotoUrl,
      alamat: alamat,
      tanggalPengantaran: tanggalPengantaran,
      waktuPengantaran: waktuPengantaran,
      catatan: catatan,
      deliveryMode: deliveryMode,
      flowStatus: flowStatus,
      pengolahUid: pengolahUid,
      pengolahNama: pengolahNama,
      pengolahTelepon: pengolahTelepon,
      catatanVerifikasi: catatanVerifikasi,
      finalPoin: finalPoin,
      qrPayload: qrPayload,
      waktuDikonfirmasi: waktuDikonfirmasi,
      waktuDiterimaPengolah: waktuDiterimaPengolah,
      waktuSelesai: waktuSelesai,
    );
  }

  factory SubmissionModel.fromMap(String id, Map<String, dynamic> map) {
    return SubmissionModel(
      id: id,
      uid: map['uid'] as String? ?? '',
      namaSumber: map['nama_sumber'] as String?,
      kategori: WasteCategoryX.fromString(map['kategori'] as String? ?? 'organik'),
      subtipe: map['subtipe'] as String? ?? '',
      beratKg: (map['berat_kg'] as num?)?.toDouble() ?? 0,
      partnerId: map['partner_id'] as String?,
      partnerName: map['partner_name'] as String?,
      status: SubmissionStatusX.fromString(map['status'] as String? ?? 'pending'),
      source: SubmissionSource.values.firstWhere(
        (e) => e.name == (map['source'] as String? ?? 'manual'),
        orElse: () => SubmissionSource.manual,
      ),
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
      fotoUrl: map['foto_url'] as String?,
      alamat: map['alamat'] as String?,
      tanggalPengantaran:
          (map['tanggal_pengantaran'] as Timestamp?)?.toDate(),
      waktuPengantaran: map['waktu_pengantaran'] as String?,
      catatan: map['catatan'] as String?,
      deliveryMode: DeliveryModeX.fromString(map['delivery_mode'] as String?),
      flowStatus: SubmissionFlowStatusX.fromString(map['flow_status'] as String?),
      pengolahUid: map['pengolah_uid'] as String?,
      pengolahNama: map['pengolah_nama'] as String?,
      pengolahTelepon: map['pengolah_telepon'] as String?,
      catatanVerifikasi: map['catatan_verifikasi'] as String?,
      finalPoin: (map['final_poin'] as num?)?.toInt(),
      qrPayload: map['qr_payload'] as String?,
      waktuDikonfirmasi: (map['waktu_dikonfirmasi'] as Timestamp?)?.toDate(),
      waktuDiterimaPengolah:
          (map['waktu_diterima_pengolah'] as Timestamp?)?.toDate(),
      waktuSelesai: (map['waktu_selesai'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'nama_sumber': namaSumber,
      'kategori': kategori.value,
      'subtipe': subtipe,
      'berat_kg': beratKg,
      'partner_id': partnerId,
      'partner_name': partnerName,
      'status': status.name,
      'source': source.name,
      'created_at': FieldValue.serverTimestamp(),
      'foto_url': fotoUrl,
      'alamat': alamat,
      'tanggal_pengantaran': tanggalPengantaran != null
          ? Timestamp.fromDate(tanggalPengantaran!)
          : null,
      'waktu_pengantaran': waktuPengantaran,
      'catatan': catatan,
      'delivery_mode': deliveryMode?.name,
      'flow_status': flowStatus.name,
    };
  }
}
