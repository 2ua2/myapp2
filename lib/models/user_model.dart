import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'PARENT' or 'parent' or 'CHILD' or 'child'
  final DateTime createdAt;
  final String? familyId; // null for child users or legacy accounts

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.createdAt,
    this.familyId,
  });

  // Case-insensitive so both 'parent' and 'PARENT' are handled
  bool get isParent => role.toUpperCase() == 'PARENT';
  bool get isChild => role.toUpperCase() == 'CHILD';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      if (familyId != null) 'familyId': familyId,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Firestore serverTimestamp returns a Timestamp; older records may be ISO strings
    DateTime createdAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    } else if (rawDate is String) {
      createdAt = DateTime.parse(rawDate);
    } else {
      createdAt = DateTime.now();
    }

    return UserModel(
      uid: map['uid'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      role: map['role'] as String,
      createdAt: createdAt,
      familyId: map['familyId'] as String?,
    );
  }
}
