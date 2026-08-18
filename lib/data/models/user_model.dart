import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final int poinSirkular;
  final String levelTitle;
  final DateTime? createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.poinSirkular = 0,
    this.levelTitle = 'Pejuang Kota Sirkular',
    this.createdAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      poinSirkular: (map['poin_sirkular'] as num?)?.toInt() ?? 0,
      levelTitle: map['level_title'] as String? ?? 'Pejuang Kota Sirkular',
      createdAt: (map['created_at'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'poin_sirkular': poinSirkular,
      'level_title': levelTitle,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({String? name, int? poinSirkular, String? levelTitle}) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      poinSirkular: poinSirkular ?? this.poinSirkular,
      levelTitle: levelTitle ?? this.levelTitle,
      createdAt: createdAt,
    );
  }
}
