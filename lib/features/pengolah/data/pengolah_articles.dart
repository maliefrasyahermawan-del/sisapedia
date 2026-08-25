/// Static content for the 3 "Artikel Seputar Pengolah" cards on Beranda —
/// previously decorative (no tap target at all); now each opens
/// `PengolahArticleDetailScreen` with content matching its title.
class PengolahArticle {
  const PengolahArticle({
    required this.title,
    required this.readTime,
    required this.paragraphs,
  });

  final String title;
  final String readTime;
  final List<String> paragraphs;
}

const pengolahArticles = [
  PengolahArticle(
    title: 'Smart Bin: Sensor Kapasitas Gudang Otomatis',
    readTime: '5 menit baca',
    paragraphs: [
      'Salah satu masalah paling umum di bank sampah dan pengepul adalah '
          'gudang yang tiba-tiba penuh tanpa peringatan — akibatnya jadwal '
          'pengangkutan jadi mendadak dan armada sering kelabakan.',
      'Sensor ultrasonik atau load-cell yang dipasang di titik penyimpanan '
          'bisa mengirim data kapasitas terisi secara real-time ke aplikasi, '
          'mirip dengan kartu "Kapasitas Gudang" yang sudah kamu lihat di '
          'Dashboard. Dengan ambang batas (misal 80%), sistem bisa otomatis '
          'kirim notifikasi jauh sebelum gudang benar-benar penuh.',
      'Investasi awal sensor cukup terjangkau (mulai dari sensor jarak '
          'ultrasonik sederhana), dan bisa disambungkan ke microcontroller '
          'murah seperti ESP32 yang mengirim data lewat WiFi. Untuk skala '
          'kecil, bahkan pencatatan manual terjadwal 2x sehari sudah cukup '
          'membantu selama konsisten dilakukan.',
      'Tips praktis: mulai dari 1 titik gudang paling sering penuh dulu, '
          'baru perluas ke titik lain kalau hasilnya positif.',
    ],
  ),
  PengolahArticle(
    title: 'Optimalkan Kandang Maggot BSF dengan IoT',
    readTime: '4 menit baca',
    paragraphs: [
      'Budidaya maggot BSF (Black Soldier Fly) makin populer sebagai cara '
          'mengolah sampah organik jadi pakan ternak bernilai ekonomi. Tapi '
          'hasil panen sangat bergantung pada suhu dan kelembapan kandang '
          'yang stabil.',
      'Sensor suhu & kelembapan (DHT22 atau sejenisnya) yang dipasang di '
          'beberapa titik kandang membantu memantau kondisi tanpa harus '
          'bolak-balik cek manual. Idealnya suhu dijaga di kisaran 27-32°C '
          'dengan kelembapan 60-70% untuk pertumbuhan larva yang optimal.',
      'Kalau kandang mulai kepanasan atau terlalu kering, sistem otomatis '
          'bisa memicu kipas atau penyemprotan air ringan — mengurangi risiko '
          'kematian massal larva yang sering jadi penyebab utama gagal panen.',
      'Bagi bank sampah yang belum punya unit maggot, ini bisa jadi opsi '
          'diversifikasi usaha di masa depan — tapi bukan keharusan, banyak '
          'pengolah yang sukses tanpa unit ini sama sekali.',
    ],
  ),
  PengolahArticle(
    title: '5 Strategi Bank Sampah Naikkan Setoran',
    readTime: '6 menit baca',
    paragraphs: [
      '1. Permudah alur setor. Semakin sedikit gesekan (foto bukti ribet, '
          'jadwal jemput yang kaku), semakin besar kemungkinan warga rutin '
          'setor. Konfirmasi cepat lewat aplikasi seperti di tab Setoran '
          'ini adalah salah satu cara mengurangi gesekan tersebut.',
      '2. Transparansi poin. Warga lebih percaya kalau mereka bisa lihat '
          'sendiri status setorannya — diterima, sedang diverifikasi, sampai '
          'poin masuk — bukan cuma janji lisan.',
      '3. Program rutin mingguan/bulanan. Jadwalkan hari setor tetap (misal '
          'tiap Sabtu pagi) supaya jadi kebiasaan, bukan aktivitas sesekali.',
      '4. Edukasi jenis sampah. Banyak warga bingung membedakan sampah yang '
          'diterima vs tidak — pemilahan yang salah bikin proses verifikasi '
          'jadi lebih lama dan kadang berujung ketidaksesuaian.',
      '5. Libatkan komunitas. Event seperti "Panen Maggot Bersama Warga" '
          'bukan cuma edukasi, tapi juga membangun rasa memiliki terhadap '
          'program bank sampah di lingkungan sekitar.',
    ],
  ),
];
