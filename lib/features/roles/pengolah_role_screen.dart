import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/providers/role_snapshot_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/session/session_mode.dart';

class PengolahRoleScreen extends ConsumerWidget {
  const PengolahRoleScreen({super.key, required this.tab});
  final int tab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(roleSnapshotProvider)
        .when(
          data: (snapshot) {
            if (snapshot.error != null) {
              return Center(child: Text(snapshot.error!));
            }
            final profile = RoleSnapshot.current.profiles.firstWhere(
              (row) =>
                  row['primary_role'] == 'pengolah' ||
                  row['processor_status'] != null,
              orElse: () => const <String, dynamic>{},
            );
            if (profile['processor_status'] == 'pending' && tab != 4) {
              return const _PendingProfile();
            }
            return switch (tab) {
              1 => _Offers(ref: ref),
              2 => _Pickup(ref: ref),
              3 => const _Capacity(),
              4 => const _Profile(),
              _ => const _Dashboard(),
            };
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Data peran belum tersedia: $error')),
        );
  }
}

class _PendingProfile extends StatelessWidget {
  const _PendingProfile();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.hourglass_top, size: 48),
          const SizedBox(height: 12),
          Text(
            'Pengajuan sedang diverifikasi',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Lengkapi profil dan bukti verifikasi. Admin akan meninjau sebelum tawaran pickup aktif.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Dashboard extends StatelessWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context) {
    final offers = RoleSnapshot.current.offers
        .where((offer) => offer['status'] == 'pending')
        .length;
    final active = RoleSnapshot.current.submissions
        .where(
          (submission) =>
              submission['partner_id'] == RoleSnapshot.currentProcessorId &&
              ['accepted', 'enRoute', 'weighed'].contains(submission['status']),
        )
        .length;
    final capacity = RoleSnapshot.current.capacities.firstWhere(
      (item) => item['processor_id'] == RoleSnapshot.currentProcessorId,
      orElse: () => <String, dynamic>{'available_kg': 0},
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Dashboard operasional',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _metric(
          'Tawaran menunggu',
          '$offers tawaran · batas 20 menit',
          Icons.inbox_outlined,
        ),
        _metric(
          'Pickup aktif',
          '$active transaksi',
          Icons.local_shipping_outlined,
        ),
        _metric(
          'Kapasitas tersedia',
          '${capacity['available_kg'] ?? 0} kg',
          Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 16),
        const Text(
          'Setiap penerimaan mengunci kapasitas sampai selesai atau dibatalkan.',
        ),
      ],
    );
  }
}

class _Offers extends StatelessWidget {
  const _Offers({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final offers = RoleSnapshot.current.offers
        .where(
          (offer) => offer['processor_id'] == RoleSnapshot.currentProcessorId,
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Permintaan masuk',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        if (offers.isEmpty) const Text('Belum ada tawaran.'),
        ...offers.map((offer) {
          final submission = RoleSnapshot.current.submissions.firstWhere(
            (row) => row['id'] == offer['submission_id'],
            orElse: () => const <String, dynamic>{},
          );
          final area =
              submission['administrative_area'] ??
              submission['district'] ??
              'Wilayah Semarang';
          return Card(
            child: ListTile(
              title: Text(
                '${submission['subtipe'] ?? 'Material'} · ${submission['berat_kg'] ?? '-'} kg',
              ),
              subtitle: Text(
                '${offer['status']} · 20 menit · $area · kapasitas dan minimum pickup sesuai profil',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Tolak',
                    onPressed: () => _run(
                      context,
                      () => ref
                          .read(submissionRepositoryProvider)
                          .rejectOffer(
                            offer['id'].toString(),
                            'Slot tidak tersedia',
                          ),
                    ),
                    icon: const Icon(Icons.close),
                  ),
                  IconButton(
                    tooltip: 'Terima',
                    onPressed: () => _run(
                      context,
                      () => ref
                          .read(submissionRepositoryProvider)
                          .acceptOffer(offer['id'].toString()),
                    ),
                    icon: const Icon(Icons.check),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _Pickup extends StatelessWidget {
  const _Pickup({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final rows = RoleSnapshot.current.submissions
        .where(
          (submission) =>
              submission['partner_id'] == RoleSnapshot.currentProcessorId &&
              [
                'accepted',
                'enRoute',
                'weighed',
                'disputed',
              ].contains(submission['status']),
        )
        .toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Pickup', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        if (rows.isEmpty) const Text('Belum ada pickup aktif.'),
        ...rows.map(
          (row) => Card(
            child: ListTile(
              title: Text(row['subtipe']?.toString() ?? 'Setoran'),
              subtitle: Text(
                '${row['status']} · ${row['berat_kg']} kg${row['precise_address'] == null ? '' : ' · ${row['precise_address']}'}',
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) => _action(context, row, value),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'enroute',
                    child: Text('Tandai berangkat'),
                  ),
                  PopupMenuItem(value: 'weigh', child: Text('Catat timbang')),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _action(
    BuildContext context,
    Map<String, dynamic> row,
    String value,
  ) async {
    try {
      final repository = ref.read(submissionRepositoryProvider);
      final id = row['id'].toString();
      if (value == 'enroute') {
        await repository.setEnRoute(id);
        return;
      }
      final weight = TextEditingController(text: row['berat_kg'].toString());
      String? evidencePath;
      if (!context.mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) => AlertDialog(
            title: const Text('Bukti timbang wajib'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: weight,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Berat aktual (kg)',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final photo = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (photo != null) {
                      setDialogState(() => evidencePath = photo.path);
                    }
                  },
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Pilih foto timbangan (wajib)'),
                ),
                if (ref.read(sessionModeProvider) == SessionMode.demo)
                  FilledButton.tonalIcon(
                    onPressed: () => setDialogState(
                      () => evidencePath = 'assets/preview/scale-evidence.png',
                    ),
                    icon: const Icon(Icons.science_outlined),
                    label: const Text('Gunakan contoh bukti timbang'),
                  ),
                if (evidencePath != null && evidencePath!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Bukti dipilih: ${_evidenceFileName(evidencePath!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Simpan'),
              ),
            ],
          ),
        ),
      );
      if (ok == true) {
        final actualWeight = double.tryParse(weight.text);
        if (actualWeight == null ||
            actualWeight <= 0 ||
            evidencePath == null ||
            evidencePath!.isEmpty) {
          throw const FormatException('Berat positif dan bukti foto wajib.');
        }
        await repository.recordWeight(id, actualWeight, evidencePath!);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Aksi gagal: $error')));
      }
    }
  }
}

class _Capacity extends StatelessWidget {
  const _Capacity();

  @override
  Widget build(BuildContext context) {
    final capacity = RoleSnapshot.current.capacities.firstWhere(
      (item) => item['processor_id'] == RoleSnapshot.currentProcessorId,
      orElse: () => <String, dynamic>{},
    );
    final total = (capacity['total_kg'] as num?)?.toDouble() ?? 1;
    final available = (capacity['available_kg'] as num?)?.toDouble() ?? 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Kapasitas', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: (available / total).clamp(0, 1)),
        const SizedBox(height: 8),
        Text(
          '${capacity['available_kg'] ?? 0} kg tersedia dari '
          '${capacity['total_kg'] ?? 0} kg',
        ),
        const SizedBox(height: 16),
        const Text(
          'Kapasitas reservasi diperbarui otomatis saat tawaran diterima.',
        ),
      ],
    );
  }
}

String _evidenceFileName(String path) => path.split(RegExp(r'[/\\]')).last;

class _Profile extends ConsumerStatefulWidget {
  const _Profile();

  @override
  ConsumerState<_Profile> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<_Profile> {
  final name = TextEditingController(text: 'Bank Sampahku Berkahmu');
  final type = TextEditingController(text: 'bank_sampah');
  final materials = TextEditingController(text: 'Organik, Plastik, Kertas');
  final capacity = TextEditingController(text: '150');
  final radius = TextEditingController(text: '10');
  final minimum = TextEditingController(text: '1');
  final address = TextEditingController(text: 'Pasar Sampangan, Semarang');
  final latitude = TextEditingController(text: '-7.023');
  final longitude = TextEditingController(text: '110.407');
  final pickupStart = TextEditingController(text: '08:00:00');
  final pickupEnd = TextEditingController(text: '17:00:00');
  String? evidencePath;
  bool active = true;
  bool pickupAvailable = true;

  @override
  void dispose() {
    for (final controller in [
      name,
      type,
      materials,
      capacity,
      radius,
      minimum,
      address,
      pickupStart,
      pickupEnd,
      latitude,
      longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Profil Pengolah',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        for (final field in [
          (name, 'Nama fasilitas'),
          (type, 'Jenis mitra'),
          (materials, 'Material diterima'),
          (capacity, 'Kapasitas total (kg)'),
          (radius, 'Radius layanan (km)'),
          (minimum, 'Minimum pickup (kg)'),
          (address, 'Alamat fasilitas'),
          (latitude, 'Pin latitude Semarang'),
          (longitude, 'Pin longitude Semarang'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: field.$1,
              decoration: InputDecoration(labelText: field.$2),
            ),
          ),
        SwitchListTile(
          title: const Text('Mitra aktif menerima pekerjaan'),
          value: active,
          onChanged: (value) => setState(() => active = value),
        ),
        SwitchListTile(
          title: const Text('Pickup tersedia'),
          value: pickupAvailable,
          onChanged: (value) => setState(() => pickupAvailable = value),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: pickupStart,
                decoration: const InputDecoration(
                  labelText: 'Pickup mulai (WIB)',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: pickupEnd,
                decoration: const InputDecoration(
                  labelText: 'Pickup selesai (WIB)',
                ),
              ),
            ),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () async {
            if (ref.read(sessionModeProvider) == SessionMode.demo) {
              setState(() => evidencePath = 'preview://application-simulated');
              return;
            }
            final photo = await ImagePicker().pickImage(
              source: ImageSource.gallery,
              imageQuality: 85,
            );
            if (photo != null && mounted) {
              setState(() => evidencePath = photo.path);
            }
          },
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(
            evidencePath == null
                ? 'Pilih bukti verifikasi'
                : 'Bukti: ${evidencePath!.split('/').last}',
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: () async {
            try {
              if (ref.read(sessionModeProvider) != SessionMode.demo &&
                  evidencePath == null) {
                throw const FormatException('Bukti verifikasi wajib dipilih.');
              }
              await ref
                  .read(partnerRepositoryProvider)
                  .updateProfile(
                    processorId: RoleSnapshot.currentProcessorId,
                    displayName: name.text,
                    processorType: type.text,
                    materials: materials.text
                        .split(',')
                        .map((e) => e.trim())
                        .where((e) => e.isNotEmpty)
                        .toList(),
                    totalCapacityKg: double.parse(capacity.text),
                    serviceRadiusKm: double.parse(radius.text),
                    minimumPickupKg: double.parse(minimum.text),
                    administrativeArea: address.text,
                    evidencePath:
                        evidencePath ?? 'preview://application-simulated',
                    latitude: double.parse(latitude.text),
                    longitude: double.parse(longitude.text),
                  );
              await ref
                  .read(partnerRepositoryProvider)
                  .updateOperational(
                    processorId: RoleSnapshot.currentProcessorId,
                    active: active,
                    pickupAvailable: pickupAvailable,
                    pickupStart: pickupStart.text.trim(),
                    pickupEnd: pickupEnd.text.trim(),
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Profil disimpan dan menunggu verifikasi Admin.',
                    ),
                  ),
                );
              }
            } catch (error) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profil belum tersimpan: $error')),
                );
              }
            }
          },
          icon: const Icon(Icons.save_outlined),
          label: const Text('Simpan pengajuan profil'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _createContentDraft(context),
          icon: const Icon(Icons.edit_note),
          label: const Text('Buat draft artikel/event'),
        ),
      ],
    );
  }

  Future<void> _createContentDraft(BuildContext context) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final eventAt = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 1))
          .toLocal()
          .toIso8601String()
          .substring(0, 16),
    );
    final eventLocation = TextEditingController();
    var selectedKind = 'article';
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Draft komunitas'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selectedKind,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(value: 'article', child: Text('Artikel')),
                    DropdownMenuItem(value: 'event', child: Text('Event')),
                  ],
                  onChanged: (value) =>
                      setState(() => selectedKind = value ?? 'article'),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Judul'),
                ),
                TextField(
                  controller: body,
                  decoration: const InputDecoration(labelText: 'Isi'),
                  maxLines: 3,
                ),
                if (selectedKind == 'event') ...[
                  TextField(
                    controller: eventAt,
                    decoration: const InputDecoration(
                      labelText: 'Jadwal (ISO, contoh 2026-08-24T09:00)',
                    ),
                  ),
                  TextField(
                    controller: eventLocation,
                    decoration: const InputDecoration(
                      labelText: 'Lokasi kegiatan',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan draft'),
          ),
        ],
      ),
    );
    final parsedEventAt = selectedKind == 'event'
        ? DateTime.tryParse(eventAt.text.trim())
        : null;
    if (saved == true && title.text.trim().isNotEmpty) {
      try {
        final repo = ref.read(contentRepositoryProvider);
        final id = await repo.createDraft(
          kind: selectedKind,
          title: title.text.trim(),
          body: body.text.trim(),
          scheduledAt: parsedEventAt,
          location: eventLocation.text.trim(),
        );
        await repo.submitDraft(id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Draft disubmit untuk moderasi Admin.'),
            ),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Draft gagal: $error')));
        }
      }
    }
    title.dispose();
    body.dispose();
    eventAt.dispose();
    eventLocation.dispose();
  }
}

Widget _metric(String title, String value, IconData icon) => Card(
  child: ListTile(
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(value),
  ),
);

Future<void> _run(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Aksi gagal: $error')));
    }
  }
}
