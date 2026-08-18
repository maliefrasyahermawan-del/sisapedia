import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/data_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/section_header.dart';

class MovementSection extends ConsumerWidget {
  const MovementSection({super.key, required this.onJoin});

  final void Function(String eventId, String title) onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(movementEventsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Movement',
          subtitle: 'Gerakan komunitas dari pengolah sekitarmu',
        ),
        const SizedBox(height: 12),
        eventsAsync.when(
          data: (events) {
            if (events.isEmpty) {
              return Text('Belum ada event komunitas.',
                  style: AppTextStyles.captionMuted);
            }
            return Column(
              children: [
                for (final event in events) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.title, style: AppTextStyles.bodyBold),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  event.organizer,
                                  if (event.date != null)
                                    DateFormat('d MMM', 'id_ID')
                                        .format(event.date!),
                                ].join(' · '),
                                style: AppTextStyles.captionMuted,
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () => onJoin(event.id, event.title),
                          child: const Text('Gabung'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Text('Gagal memuat event.',
              style: AppTextStyles.captionMuted.copyWith(color: AppColors.error)),
        ),
      ],
    );
  }
}
