class ArticleModel {
  final String id;
  final String title;
  final String summary;
  final String content;
  final int readTimeMinutes;
  final String? imageUrl;

  const ArticleModel({
    required this.id,
    required this.title,
    required this.summary,
    this.content = '',
    this.readTimeMinutes = 3,
    this.imageUrl,
  });

  factory ArticleModel.fromMap(String id, Map<String, dynamic> map) {
    return ArticleModel(
      id: id,
      title: map['title'] as String? ?? '',
      summary: map['summary'] as String? ?? '',
      content: map['content'] as String? ?? '',
      readTimeMinutes: (map['read_time_minutes'] as num?)?.toInt() ?? 3,
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'summary': summary,
      'content': content,
      'read_time_minutes': readTimeMinutes,
      'image_url': imageUrl,
    };
  }
}
