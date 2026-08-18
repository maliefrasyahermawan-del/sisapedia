import 'package:firebase_auth/firebase_auth.dart';

String mapAuthError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'Email atau kata sandi salah.';
      case 'wrong-password':
        return 'Email atau kata sandi salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Coba masuk.';
      case 'weak-password':
        return 'Kata sandi minimal 6 karakter.';
      case 'network-request-failed':
        return 'Koneksi internet bermasalah.';
      default:
        return 'Terjadi kesalahan (${error.code}). Coba lagi.';
    }
  }
  return 'Terjadi kesalahan. Coba lagi.';
}
