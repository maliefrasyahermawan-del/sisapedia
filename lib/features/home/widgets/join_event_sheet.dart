import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class JoinEventResult {
  final String kontak;
  final String motivasi;
  const JoinEventResult({required this.kontak, required this.motivasi});
}

Future<void> showJoinEventSheet(
  BuildContext context, {
  required String eventTitle,
  required String organizer,
  required String defaultName,
  required Future<void> Function(JoinEventResult result) onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _JoinEventForm(
      eventTitle: eventTitle,
      organizer: organizer,
      defaultName: defaultName,
      onSubmit: onSubmit,
    ),
  );
}

class _JoinEventForm extends StatefulWidget {
  const _JoinEventForm({
    required this.eventTitle,
    required this.organizer,
    required this.defaultName,
    required this.onSubmit,
  });

  final String eventTitle;
  final String organizer;
  final String defaultName;
  final Future<void> Function(JoinEventResult result) onSubmit;

  @override
  State<_JoinEventForm> createState() => _JoinEventFormState();
}

class _JoinEventFormState extends State<_JoinEventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  final _kontakController = TextEditingController();
  final _motivasiController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _kontakController.dispose();
    _motivasiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    await widget.onSubmit(
      JoinEventResult(
        kontak: _kontakController.text.trim(),
        motivasi: _motivasiController.text.trim(),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gabung Event', style: AppTextStyles.h2),
                const SizedBox(height: 4),
                Text(
                  '${widget.eventTitle} · ${widget.organizer}',
                  style: AppTextStyles.captionMuted,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _kontakController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'No. HP/WhatsApp',
                    hintText: '08xxxxxxxxxx',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Kontak wajib diisi supaya pengolah bisa menghubungimu'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _motivasiController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivasi bergabung',
                    hintText: 'Ceritakan alasanmu ikut event ini...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Motivasi wajib diisi'
                      : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Data ini akan dikirim ke akun pengolah penyelenggara untuk ditinjau.',
                        style: AppTextStyles.captionMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Ajukan Gabung'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
