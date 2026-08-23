import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

abstract class AuthRepositoryBase {
  Stream<String?> get uidChanges;
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String role = 'sumber',
  });
  Future<void> signIn({required String email, required String password});
  Future<void> resetPasswordForEmail(String email);
  Future<void> signOut();
  Stream<UserModel?> watchProfile(String uid);
  Future<UserModel?> getProfile(String uid);
  Future<void> sendPhoneOtp(String phone) async =>
      throw UnsupportedError('OTP belum dikonfigurasi');
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async => throw UnsupportedError('OTP belum dikonfigurasi');
  Future<void> linkPhone(String phone) async =>
      throw UnsupportedError('Phone linking belum dikonfigurasi');
  Future<void> verifyLinkedPhoneOtp({
    required String phone,
    required String token,
  }) async => throw UnsupportedError('Phone linking belum dikonfigurasi');
}

class AuthRepository implements AuthRepositoryBase {
  AuthRepository({SupabaseClient? client}) : _client = client ?? _tryClient();
  final SupabaseClient? _client;
  static SupabaseClient? _tryClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<String?> get uidChanges => _client == null
      ? Stream.value(null)
      : _client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
    String role = 'sumber',
  }) async {
    final safeRole = role == 'pengolah' ? 'pengolah' : 'sumber';
    final result = await _required.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'primary_role': safeRole},
    );
    final user = result.user;
    if (user == null) throw StateError('Pendaftaran gagal');
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _required.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> resetPasswordForEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw const FormatException('Email wajib diisi');
    }
    await _required.auth.resetPasswordForEmail(normalizedEmail);
  }

  @override
  Future<void> signOut() => _required.auth.signOut();
  @override
  Stream<UserModel?> watchProfile(String uid) {
    if (_client == null) return Stream.value(null);
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map(
          (rows) => rows.isEmpty ? null : UserModel.fromMap(uid, rows.first),
        );
  }

  @override
  Future<UserModel?> getProfile(String uid) async {
    if (_client == null) return null;
    final rows = await _client.from('profiles').select().eq('id', uid).limit(1);
    return rows.isEmpty
        ? null
        : UserModel.fromMap(uid, Map<String, dynamic>.from(rows.first));
  }

  @override
  Future<void> sendPhoneOtp(String phone) async {
    await _required.auth.signInWithOtp(phone: phone);
  }

  @override
  Future<void> verifyPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _required.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
  }

  @override
  Future<void> linkPhone(String phone) async {
    if (phone.trim().isEmpty) {
      throw const FormatException('Nomor telepon wajib diisi');
    }
    await _required.auth.updateUser(UserAttributes(phone: phone.trim()));
  }

  @override
  Future<void> verifyLinkedPhoneOtp({
    required String phone,
    required String token,
  }) async {
    await _required.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.phoneChange,
    );
  }

  SupabaseClient get _required =>
      _client ??
      (throw StateError('Supabase belum dikonfigurasi. Gunakan Preview Mode.'));
}
