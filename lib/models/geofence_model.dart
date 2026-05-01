import 'package:cloud_firestore/cloud_firestore.dart';

class GeofenceModel {
  final String geofenceId;
  final String familyId;
  final String name;
  final double latitude;
  final double longitude;
  final double radius;
  final bool isActive;
  final DateTime createdAt;

  GeofenceModel({
    required this.geofenceId,
    required this.familyId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.isActive,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'geofenceId': geofenceId,
      'familyId': familyId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GeofenceModel.fromMap(Map<String, dynamic> map) {
    DateTime createdAt;
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      createdAt = rawDate.toDate();
    } else if (rawDate is String) {
      createdAt = DateTime.parse(rawDate);
    } else {
      createdAt = DateTime.now();
    }

    return GeofenceModel(
      geofenceId: map['geofenceId'] as String,
      familyId: map['familyId'] as String,
      name: map['name'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      isActive: map['isActive'] as bool? ?? true,
      createdAt: createdAt,
    );
  }

  factory GeofenceModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return GeofenceModel.fromMap(doc.data()!);
  }
}
