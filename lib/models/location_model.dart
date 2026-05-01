import 'package:cloud_firestore/cloud_firestore.dart';

class LocationModel {
  final String locationId;
  final String childId;
  final String familyId;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;

  LocationModel({
    required this.locationId,
    required this.childId,
    required this.familyId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
  });

  Map<String, dynamic> toMap() {
    return {
      'locationId': locationId,
      'childId': childId,
      'familyId': familyId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      if (accuracy != null) 'accuracy': accuracy,
      if (speed != null) 'speed': speed,
    };
  }

  factory LocationModel.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is String) {
      timestamp = DateTime.parse(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    return LocationModel(
      locationId: map['locationId'] as String,
      childId: map['childId'] as String,
      familyId: map['familyId'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      timestamp: timestamp,
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
    );
  }

  factory LocationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return LocationModel.fromMap(doc.data()!);
  }
}
