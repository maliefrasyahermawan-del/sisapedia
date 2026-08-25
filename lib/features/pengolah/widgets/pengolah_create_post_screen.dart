import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../pengolah_colors.dart';

class PengolahCreatePostScreen extends StatefulWidget {
  const PengolahCreatePostScreen({super.key});

  @override
  State<PengolahCreatePostScreen> createState() =>
      _PengolahCreatePostScreenState();
}

class _PengolahCreatePostScreenState extends State<PengolahCreatePostScreen> {
  bool _isEvent = true;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _publish() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Judul wajib diisi.')),
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEvent
            ? 'Event "${_titleController.text.trim()}" dipublikasikan.'
            : 'Postingan "${_titleController.text.trim()}" dipublikasikan.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Buat Event / Postingan'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(
                child: _TypeChip(
                  label: 'Event',
                  selected: _isEvent,
                  onTap: () => setState(() => _isEvent = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TypeChip(
                  label: 'Postingan',
                  selected: !_isEvent,
                  onTap: () => setState(() => _isEvent = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.textMuted, size: 26),
                const SizedBox(height: 6),
                Text('Tambah Foto', style: AppTextStyles.captionMuted),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Judul', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Contoh: Panen Maggot Bersama Warga',
            ),
          ),
          const SizedBox(height: 14),
          Text('Deskripsi', style: AppTextStyles.caption),
          const SizedBox(height: 6),
          TextField(
            controller: _descController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Ceritakan detail event atau postinganmu...',
            ),
          ),
          if (_isEvent) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tanggal & Waktu', style: AppTextStyles.caption),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _dateController,
                        decoration:
                            const InputDecoration(hintText: '24 Agu, 09:00'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lokasi', style: AppTextStyles.caption),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _locationController,
                        decoration: const InputDecoration(
                            hintText: 'Balai RW 04 Tembalang'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _publish,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Publikasikan'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? PengolahColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyBold
              .copyWith(color: selected ? Colors.white : AppColors.textSecondary),
        ),
      ),
    );
  }
}
