import 'package:cloud_firestore/cloud_firestore.dart';

class SosAlertModel {
  final String alertId;
  final String childId;
  final String familyId;
  final String childName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isResolved;

  SosAlertModel({
    required this.alertId,
    required this.childId,
    required this.familyId,
    required this.childName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isResolved,
  });

  Map<String, dynamic> toMap() {
    return {
      'alertId': alertId,
      'childId': childId,
      'familyId': familyId,
      'childName': childName,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'isResolved': isResolved,
    };
  }

  factory SosAlertModel.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is String) {
      timestamp = DateTime.parse(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    return SosAlertModel(
      alertId: map['alertId'] as String,
      childId: map['childId'] as String,
      familyId: map['familyId'] as String,
      childName: map['childName'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: timestamp,
      isResolved: map['isResolved'] as bool? ?? false,
    );
  }

  factory SosAlertModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return SosAlertModel.fromMap(doc.data()!);
  }
}
