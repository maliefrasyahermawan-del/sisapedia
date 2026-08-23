import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/submission_model.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final SubmissionStatus status;

  Color get _color {
    switch (status) {
      case SubmissionStatus.verified:
        return AppColors.success;
      case SubmissionStatus.pending:
        return AppColors.warning;
      case SubmissionStatus.rejected:
        return AppColors.error;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
