class UserModel {
  final String uid;
  final String name;
  final String email;
  final int poinSirkular;
  final String levelTitle;
  final DateTime? createdAt;
  final String primaryRole;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.poinSirkular = 0,
    this.levelTitle = 'Pejuang Kota Sirkular',
    this.createdAt,
    this.primaryRole = 'sumber',
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      poinSirkular: (map['poin_sirkular'] as num?)?.toInt() ?? 0,
      levelTitle: map['level_title'] as String? ?? 'Pejuang Kota Sirkular',
      createdAt: _userDate(map['created_at']),
      primaryRole: map['primary_role'] as String? ?? 'sumber',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'poin_sirkular': poinSirkular,
      'level_title': levelTitle,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'primary_role': primaryRole,
    };
  }

  UserModel copyWith({
    String? name,
    int? poinSirkular,
    String? levelTitle,
    String? primaryRole,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      poinSirkular: poinSirkular ?? this.poinSirkular,
      levelTitle: levelTitle ?? this.levelTitle,
      createdAt: createdAt,
      primaryRole: primaryRole ?? this.primaryRole,
    );
  }
}

DateTime? _userDate(dynamic value) => value is DateTime
    ? value
    : value is String
    ? DateTime.tryParse(value)
    : null;
