import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text styles built on Manrope, matching the design source.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    Color color = AppColors.textPrimary,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );
  }

  static TextStyle get brand =>
      _base(size: 20, weight: FontWeight.w800, color: AppColors.textOnPrimary);

  static TextStyle get h1 => _base(size: 22, weight: FontWeight.w800);
  static TextStyle get h2 => _base(size: 18, weight: FontWeight.w700);
  static TextStyle get h3 => _base(size: 16, weight: FontWeight.w700);

  static TextStyle get bodyBold =>
      _base(size: 14, weight: FontWeight.w700);
  static TextStyle get body => _base(size: 14, weight: FontWeight.w500);
  static TextStyle get bodySmall => _base(size: 13, weight: FontWeight.w500);

  static TextStyle get caption =>
      _base(size: 12, weight: FontWeight.w600, color: AppColors.textSecondary);
  static TextStyle get captionMuted =>
      _base(size: 12, weight: FontWeight.w500, color: AppColors.textMuted);

  static TextStyle get button =>
      _base(size: 14, weight: FontWeight.w700, color: AppColors.textOnPrimary);

  static TextStyle get statValue =>
      _base(size: 24, weight: FontWeight.w800);
}
