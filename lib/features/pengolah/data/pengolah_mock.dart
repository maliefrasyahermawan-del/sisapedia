import 'package:flutter/material.dart';

/// Mock data for the Pengolah (waste processor) testing account. Entirely
/// local/in-memory — no Firestore, no shared repository providers, kept
/// isolated from the Sumber app's data layer on purpose.
class PengolahSubmissionItem {
  const PengolahSubmissionItem({required this.jenis, required this.berat});

  final String jenis;
  final String berat;
}

class PengolahSubmission {
  const PengolahSubmission({
    required this.nama,
    required this.ringkas,
    required this.iconBg,
    required this.alamat,
    required this.telepon,
    required this.items,
  });

  final String nama;
  final String ringkas;
  final Color iconBg;
  final String alamat;
  final String telepon;
  final List<PengolahSubmissionItem> items;
}

class PengolahEvent {
  const PengolahEvent({required this.title, required this.meta});

  final String title;
  final String meta;
}

const pengolahNamaAkun = 'Bank Sampah Melati Bersih';

const pengolahSubmissions = [
  PengolahSubmission(
    nama: 'Warung Bu Sri',
    ringkas: 'Organik · 4.2 kg · Diajukan 12 menit lalu',
    iconBg: Color(0xFFDDF3E7),
    alamat: 'Jl. Tembalang Selatan No. 12, Semarang',
    telepon: '0812-3456-7890',
    items: [
      PengolahSubmissionItem(jenis: 'Sisa Sayur', berat: '2.6 kg'),
      PengolahSubmissionItem(jenis: 'Sisa Buah', berat: '1.6 kg'),
    ],
  ),
  PengolahSubmission(
    nama: 'Budi Santoso',
    ringkas: 'Anorganik · 3.1 kg · Diajukan 40 menit lalu',
    iconBg: Color(0xFFDCE8FD),
    alamat: 'Jl. Setiabudi Raya No. 45, Semarang',
    telepon: '0813-9988-2211',
    items: [
      PengolahSubmissionItem(jenis: 'Botol Plastik PET', berat: '1.4 kg'),
      PengolahSubmissionItem(jenis: 'Kardus', berat: '1.7 kg'),
    ],
  ),
];

const pengolahEvents = [
  PengolahEvent(
    title: 'Panen Maggot Bersama Warga',
    meta: '24 Agu, 09:00 · Balai RW 04 Tembalang',
  ),
];
