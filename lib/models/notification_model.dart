import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final String childId;
  final String familyId;
  final String alertId;
  final DateTime timestamp;
  final bool isRead;
  // SOS-specific metadata; null for non-SOS notification types.
  final DateTime? sosTime;
  final double? sosLat;
  final double? sosLng;
  final String? sosAddress;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.childId,
    required this.familyId,
    required this.alertId,
    required this.timestamp,
    required this.isRead,
    this.sosTime,
    this.sosLat,
    this.sosLng,
    this.sosAddress,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'childId': childId,
      'familyId': familyId,
      'alertId': alertId,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
      if (sosTime != null) 'sosTime': Timestamp.fromDate(sosTime!),
      if (sosLat != null) 'sosLat': sosLat,
      if (sosLng != null) 'sosLng': sosLng,
      if (sosAddress != null) 'sosAddress': sosAddress,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime timestamp;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is String) {
      timestamp = DateTime.parse(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    DateTime? sosTime;
    final rawSosTs = map['sosTime'];
    if (rawSosTs is Timestamp) {
      sosTime = rawSosTs.toDate();
    } else if (rawSosTs is String) {
      sosTime = DateTime.tryParse(rawSosTs);
    }

    return NotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? '',
      childId: map['childId'] as String? ?? '',
      familyId: map['familyId'] as String? ?? '',
      alertId: map['alertId'] as String? ?? '',
      timestamp: timestamp,
      isRead: map['isRead'] as bool? ?? false,
      sosTime: sosTime,
      sosLat: (map['sosLat'] as num?)?.toDouble(),
      sosLng: (map['sosLng'] as num?)?.toDouble(),
      sosAddress: map['sosAddress'] as String?,
    );
  }
}
