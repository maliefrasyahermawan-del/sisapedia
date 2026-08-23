class MovementEventModel {
  final String id;
  final String title;
  final String organizer;
  final DateTime? date;
  final String location;
  final String? imageUrl;

  const MovementEventModel({
    required this.id,
    required this.title,
    required this.organizer,
    this.date,
    this.location = '',
    this.imageUrl,
  });

  factory MovementEventModel.fromMap(String id, Map<String, dynamic> map) {
    return MovementEventModel(
      id: id,
      title: map['title'] as String? ?? '',
      organizer: map['organizer'] as String? ?? '',
      date: map['date'] is String
          ? DateTime.tryParse(map['date'] as String)
          : map['date'] as DateTime?,
      location: map['location'] as String? ?? '',
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'organizer': organizer,
      'date': date?.toUtc().toIso8601String(),
      'location': location,
      'image_url': imageUrl,
    };
  }
}
