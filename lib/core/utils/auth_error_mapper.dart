String mapAuthError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('invalid login') ||
      message.contains('invalid credentials')) {
    return 'Email atau kata sandi salah.';
  }
  if (message.contains('already registered') ||
      message.contains('already exists')) {
    return 'Email sudah terdaftar.';
  }
  if (message.contains('password')) {
    return 'Kata sandi minimal 6 karakter.';
  }
  if (message.contains('network') || message.contains('socket')) {
    return 'Koneksi bermasalah. Coba lagi atau gunakan Preview Mode.';
  }
  return 'Terjadi kendala. Periksa data lalu coba lagi.';
}
