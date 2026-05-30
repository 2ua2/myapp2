import 'package:cloud_firestore/cloud_firestore.dart';

class AlarmAlertModel {
  final String alertId;
  final String childId;
  final String familyId;
  final String childName;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final bool isResolved;
  // Reverse-geocoded address; null for documents written before geocoding ran.
  final String? sosAddress;

  AlarmAlertModel({
    required this.alertId,
    required this.childId,
    required this.familyId,
    required this.childName,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.isResolved,
    this.sosAddress,
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
      if (sosAddress != null) 'sosAddress': sosAddress,
    };
  }

  factory AlarmAlertModel.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is String) {
      timestamp = DateTime.parse(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    return AlarmAlertModel(
      // alertId is the Firestore document key, not a stored field. Callers
      // should merge {'alertId': doc.id} into the map before calling fromMap().
      alertId: map['alertId'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      familyId: map['familyId'] as String? ?? '',
      childName: map['childName'] as String? ?? '',
      // sendAlarmAlert() writes 'lat'/'lng'; fall back to those if the canonical
      // 'latitude'/'longitude' keys are absent.
      latitude: (map['latitude'] as num?)?.toDouble() ??
          (map['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ??
          (map['lng'] as num?)?.toDouble() ?? 0.0,
      timestamp: timestamp,
      isResolved: map['isResolved'] as bool? ?? false,
      sosAddress: map['sosAddress'] as String?,
    );
  }

  factory AlarmAlertModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    // Merge the document ID so fromMap() can populate alertId correctly.
    final map = <String, dynamic>{...doc.data()!, 'alertId': doc.id};
    return AlarmAlertModel.fromMap(map);
  }
}
