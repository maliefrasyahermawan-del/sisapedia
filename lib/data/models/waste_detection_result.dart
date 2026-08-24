import 'submission_model.dart';

enum WasteConfidence { tinggi, sedang, rendah }

extension WasteConfidenceX on WasteConfidence {
  static WasteConfidence fromString(String value) {
    return WasteConfidence.values.firstWhere(
      (e) => e.name == value.toLowerCase(),
      orElse: () => WasteConfidence.sedang,
    );
  }

  String get label {
    switch (this) {
      case WasteConfidence.tinggi:
        return 'Tinggi';
      case WasteConfidence.sedang:
        return 'Sedang';
      case WasteConfidence.rendah:
        return 'Rendah';
    }
  }
}

/// Result of analyzing a waste photo with Gemini Vision. Deliberately has
/// no weight field — a photo alone isn't a reliable scale, so `beratKg`
/// always stays a manual, user-confirmed entry on the confirmation screen.
class WasteDetectionResult {
  const WasteDetectionResult({
    required this.kategori,
    required this.jenisMaterial,
    required this.subJenis,
    required this.confidence,
    this.estimasiJumlah,
  });

  final WasteCategory kategori;
  final String jenisMaterial;
  final String subJenis;
  final int? estimasiJumlah;
  final WasteConfidence confidence;

  factory WasteDetectionResult.fromJson(Map<String, dynamic> json) {
    return WasteDetectionResult(
      kategori: WasteCategoryX.fromString(
        (json['kategori'] as String? ?? 'organik').toLowerCase(),
      ),
      jenisMaterial: json['jenis_material'] as String? ?? 'Tidak diketahui',
      subJenis: json['sub_jenis'] as String? ?? '',
      estimasiJumlah: (json['estimasi_jumlah'] as num?)?.toInt(),
      confidence: WasteConfidenceX.fromString(
        json['confidence'] as String? ?? 'sedang',
      ),
    );
  }
}
