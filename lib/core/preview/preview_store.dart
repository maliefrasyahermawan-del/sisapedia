import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Versioned, reactive local domain store for the competition build. The
/// collection names intentionally mirror the Supabase tables so Preview and
/// normal mode exercise the same repository contracts.
class PreviewStore {
  static const schemaVersion = 2;
  static SharedPreferences? _prefs;
  static final _changes = StreamController<int>.broadcast();
  static int _revision = 0;
  static Map<String, dynamic> _state = <String, dynamic>{};

  static Stream<int> get changes => _changes.stream;
  static String get role => _state['role'] as String? ?? 'sumber';
  static set role(String value) => _state['role'] = _validRole(value);
  static Future<void> setRole(String value) async {
    role = value;
    await save();
  }

  static List<Map<String, dynamic>> get submissions =>
      _collection('submissions');
  static set submissions(List<Map<String, dynamic>> value) =>
      _state['submissions'] = value;
  static List<Map<String, dynamic>> get points => _collection('point_ledger');
  static set points(List<Map<String, dynamic>> value) =>
      _state['point_ledger'] = value;
  static List<Map<String, dynamic>> get profiles => _collection('profiles');
  static List<Map<String, dynamic>> get locations => _collection('locations');
  static List<Map<String, dynamic>> get candidates =>
      _collection('match_candidates');
  static List<Map<String, dynamic>> get offers => _collection('offers');
  static List<Map<String, dynamic>> get transactions =>
      _collection('transactions');
  static List<Map<String, dynamic>> get capacities => _collection('capacities');
  static List<Map<String, dynamic>> get redeems =>
      _collection('redeem_requests');
  static List<Map<String, dynamic>> get notifications =>
      _collection('notifications');

  /// Canonical persisted audit collection. All repositories use this key.
  static List<Map<String, dynamic>> get audits => _collection('audit_events');
  static List<Map<String, dynamic>> get content =>
      _collection('content_drafts');
  static Map<String, dynamic> get formula =>
      Map<String, dynamic>.from(_state['formula'] as Map? ?? const {});

  static Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs?.getString('preview_state_v2');
    if (raw == null) {
      _state = _copyState(_seed());
      await save();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schema_version'] != schemaVersion) {
        _state = _copyState(_seed());
      } else {
        _state = _copyState(decoded);
      }
    } catch (_) {
      _state = _copyState(_seed());
    }
    _emit();
  }

  static List<Map<String, dynamic>> _collection(String name) {
    final raw = _state[name];
    if (raw is List<Map<String, dynamic>>) return raw;
    final normalized = (raw as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    _state[name] = normalized;
    return normalized;
  }

  static Map<String, dynamic> _copyState(Map<dynamic, dynamic> source) => {
    'schema_version': schemaVersion,
    'role': _validRole(source['role']?.toString() ?? 'sumber'),
    for (final key in const [
      'profiles',
      'locations',
      'submissions',
      'match_candidates',
      'offers',
      'transactions',
      'capacities',
      'point_ledger',
      'redeem_requests',
      'notifications',
      'audit_events',
      'content_drafts',
    ])
      key:
          ((source[key] ?? (key == 'audit_events' ? source['audits'] : null))
                      as List? ??
                  const [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
    'formula': Map<String, dynamic>.from(source['formula'] as Map? ?? const {}),
  };

  static Future<void> save() async {
    _state['schema_version'] = schemaVersion;
    await _prefs?.setString('preview_state_v2', jsonEncode(_state));
    _emit();
  }

  /// Atomically restores deterministic actors, both material branches, and a
  /// complete offer/transaction demo state. Existing repository streams see
  /// the same revision and refresh immediately.
  static Future<void> reset() async {
    _state = _copyState(_seed());
    await save();
  }

  static void _emit() {
    _revision++;
    if (!_changes.isClosed) _changes.add(_revision);
  }

  static String _validRole(String value) =>
      const {'sumber', 'pengolah', 'dlh', 'admin'}.contains(value)
      ? value
      : 'sumber';

  static Map<String, dynamic> _seed() {
    final now = DateTime.now().toUtc();
    String ago(int days) =>
        now.subtract(Duration(days: days)).toIso8601String();
    return {
      'schema_version': schemaVersion,
      'role': 'sumber',
      'profiles': [
        {
          'id': 'preview-sumber',
          'name': 'Bu Siti',
          'email': 'siti@preview.local',
          'primary_role': 'sumber',
          'city': 'Semarang',
          'identity': 'Pasar Sampangan',
        },
        {
          'id': 'preview-pengolah',
          'name': 'Pak Bambang',
          'email': 'bambang@preview.local',
          'primary_role': 'pengolah',
          'city': 'Semarang',
          'identity': 'Bank Sampahku Berkahmu',
          'processor_status': 'approved',
        },
        {
          'id': 'preview-dlh',
          'name': 'DLH Semarang',
          'email': 'dlh@preview.local',
          'primary_role': 'dlh',
          'city': 'Semarang',
        },
        {
          'id': 'preview-admin',
          'name': 'Admin SisaPedia',
          'email': 'admin@preview.local',
          'primary_role': 'admin',
          'city': 'Semarang',
        },
      ],
      'locations': [
        {
          'id': 'loc-siti',
          'user_id': 'preview-sumber',
          'district': 'Banyumanik',
          'administrative_area': 'Pasar Sampangan',
          'latitude': -7.023,
          'longitude': 110.407,
        },
      ],
      'submissions': [
        {
          'id': 'organic-1',
          'uid': 'preview-sumber',
          'kategori': 'organik',
          'subtipe': 'Sisa Sayur & Buah',
          'berat_kg': 2.4,
          'status': 'offered',
          'partner_id': 'preview-pengolah',
          'partner_name': 'Bank Sampahku Berkahmu',
          'source': 'manual',
          'created_at': ago(1),
        },
        {
          'id': 'inorganic-1',
          'uid': 'preview-sumber',
          'kategori': 'anorganik',
          'subtipe': 'Botol Plastik PET',
          'berat_kg': 1.8,
          'status': 'completed',
          'partner_id': 'preview-pengolah',
          'partner_name': 'Bank Sampahku Berkahmu',
          'source': 'manual',
          'created_at': ago(9),
        },
      ],
      'match_candidates': [
        {
          'id': 'candidate-organic-1',
          'submission_id': 'organic-1',
          'processor_id': 'preview-pengolah',
          'rank': 1,
          'compatibility_score': .95,
          'distance_score': .84,
          'capacity_score': .8,
          'total_score': .9,
        },
      ],
      'offers': [
        {
          'id': 'offer-organic-1',
          'submission_id': 'organic-1',
          'processor_id': 'preview-pengolah',
          'candidate_rank': 1,
          'status': 'pending',
          'expires_at': now.add(const Duration(minutes: 20)).toIso8601String(),
        },
      ],
      'transactions': [
        {
          'id': 'transaction-inorganic-1',
          'submission_id': 'inorganic-1',
          'processor_id': 'preview-pengolah',
          'actual_weight_kg': 1.8,
          'evidence_path': 'assets/preview/scale-evidence.png',
          'formula_version': 'semarang-2026-v1',
          'completed_at': ago(8),
        },
      ],
      'capacities': [
        {
          'processor_id': 'preview-pengolah',
          'total_kg': 150.0,
          'available_kg': 118.2,
          'reserved_kg': 1.8,
        },
      ],
      'point_ledger': [
        {
          'id': 'ledger-inorganic-1',
          'uid': 'preview-sumber',
          'entry_type': 'earn',
          'jumlah': 18,
          'points': 18,
          'deskripsi': 'Botol Plastik PET · 1,8 kg',
          'status': 'posted',
          'transaction_id': 'transaction-inorganic-1',
          'created_at': ago(8),
        },
      ],
      'redeem_requests': [
        {
          'id': 'redeem-preview-1',
          'uid': 'preview-sumber',
          'points': 10,
          'description': 'Voucher kompos demo',
          'status': 'submitted',
          'created_at': ago(2),
        },
      ],
      'notifications': [
        {
          'id': 'notification-1',
          'uid': 'preview-sumber',
          'title': 'Tawaran mitra baru',
          'body': 'Pak Bambang memiliki waktu 20 menit untuk merespons.',
          'kind': 'offer',
          'read': false,
          'created_at': ago(0),
        },
      ],
      'audit_events': [
        {
          'id': 'audit-seed-1',
          'actor_id': 'preview-admin',
          'action': 'seed_reset',
          'entity_type': 'preview',
          'metadata': {'version': schemaVersion},
          'created_at': ago(0),
        },
      ],
      'formula': {
        'version': 'semarang-2026-v1',
        'points_per_kg': 10,
        'emissions_factor': 1.4,
        'economic_factor': 1.0,
        'monthly_target_kg': 2000,
      },
    };
  }
}
