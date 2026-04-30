import 'package:cloud_firestore/cloud_firestore.dart';

class ChildModel {
  final String childId;
  final String familyId;
  final DateTime linkedAt;
  final bool isActive;

  ChildModel({
    required this.childId,
    required this.familyId,
    required this.linkedAt,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'childId': childId,
      'familyId': familyId,
      'linkedAt': linkedAt.toIso8601String(),
      'isActive': isActive,
    };
  }

  factory ChildModel.fromMap(Map<String, dynamic> map) {
    DateTime linkedAt;
    final raw = map['linkedAt'];
    if (raw is Timestamp) {
      linkedAt = raw.toDate();
    } else if (raw is String) {
      linkedAt = DateTime.parse(raw);
    } else {
      linkedAt = DateTime.now();
    }

    return ChildModel(
      childId: map['childId'] as String,
      familyId: map['familyId'] as String,
      linkedAt: linkedAt,
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}
