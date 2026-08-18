class InsightModel {
  final String text;
  final List<String> tags;
  final DateTime generatedAt;

  const InsightModel({
    required this.text,
    this.tags = const [],
    required this.generatedAt,
  });
}
