/// Simple estimate shown before admin verification actually credits points.
/// Shared by every setor flow (manual, voice, foto) so the number is
/// consistent wherever it's previewed.
int estimatedPoinFromKg(double beratKg) => (beratKg * 10).round();

/// Pure presentation helper deriving a gamified level/progress ring from
/// `poinSirkular`. Not a backend field — purely derived for the UI.
class LevelProgress {
  const LevelProgress({
    required this.level,
    required this.progress,
    required this.poinIntoLevel,
    required this.poinRemaining,
  });

  /// 1-based level number.
  final int level;

  /// 0.0–1.0 progress within the current level band.
  final double progress;

  final int poinIntoLevel;
  final int poinRemaining;

  static const _poinPerLevel = 2000;

  factory LevelProgress.fromPoin(int poin) {
    final level = (poin ~/ _poinPerLevel) + 1;
    final poinIntoLevel = poin % _poinPerLevel;
    final poinRemaining = _poinPerLevel - poinIntoLevel;
    return LevelProgress(
      level: level,
      progress: poinIntoLevel / _poinPerLevel,
      poinIntoLevel: poinIntoLevel,
      poinRemaining: poinRemaining,
    );
  }
}
