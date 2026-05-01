import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String uid;
  final String title;
  final String body;
  final String type;
  final bool isRead;
  final DateTime timestamp;
  final Map<String, dynamic>? payload;

  NotificationModel({
    required this.notificationId,
    required this.uid,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.timestamp,
    this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'uid': uid,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'timestamp': timestamp.toIso8601String(),
      if (payload != null) 'payload': payload,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime timestamp;
    final rawTs = map['timestamp'];
    if (rawTs is Timestamp) {
      timestamp = rawTs.toDate();
    } else if (rawTs is String) {
      timestamp = DateTime.parse(rawTs);
    } else {
      timestamp = DateTime.now();
    }

    return NotificationModel(
      notificationId: map['notificationId'] as String,
      uid: map['uid'] as String,
      title: map['title'] as String,
      body: map['body'] as String,
      type: map['type'] as String,
      isRead: map['isRead'] as bool? ?? false,
      timestamp: timestamp,
      payload: map['payload'] as Map<String, dynamic>?,
    );
  }

  factory NotificationModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return NotificationModel.fromMap(doc.data()!);
  }
}
