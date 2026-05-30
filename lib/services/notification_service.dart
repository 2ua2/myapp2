import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/alarm_alert_model.dart';
import '../models/notification_model.dart';
import '../models/sos_alert_model.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<bool> sendSosAlert({
    required String childId,
    required String familyId,
    required double lat,
    required double lng,
    required String childName,
  }) async {
    final alertId = const Uuid().v4();
    final now = DateTime.now();
    final sosTimestamp = Timestamp.fromDate(now);

    // Write the SOS alert document first — critical, abort on failure.
    try {
      final dataMap = <String, dynamic>{
        'childId': childId,
        'familyId': familyId,
        'lat': lat,
        'lng': lng,
        'childName': childName,
        'timestamp': sosTimestamp,
        'status': 'unresolved',
        'sosTime': sosTimestamp,
        'sosLat': lat,
        'sosLng': lng,
      };
      print('[SVC-SOS-WRITE] familyId=$familyId childId=$childId fields=${dataMap.toString()}');
      await _firestore.collection('sos_alerts').doc(alertId).set(dataMap);
    } catch (e) {
      print('sendSosAlert ERROR: $e');
      return false;
    }

    // Reverse-geocode the SOS coordinates to a human-readable address.
    // Falls back to raw coordinates so geocoding never blocks the alert.
    String sosAddress;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) throw Exception('empty placemarks');
      final p = placemarks.first;
      final parts = <String>[
        if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        if (p.country != null && p.country!.isNotEmpty) p.country!,
      ];
      sosAddress = parts.isNotEmpty
          ? parts.join(', ')
          : 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
    } catch (_) {
      sosAddress = 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
    }

    // Stamp the resolved address onto the sos_alerts document (best effort).
    try {
      await _firestore
          .collection('sos_alerts')
          .doc(alertId)
          .update({'sosAddress': sosAddress});
    } catch (e) {
      print('sendSosAlert sosAddress update ERROR: $e');
    }

    // Compose the notification body: "SOS at HH:mm, dd MMM yyyy\naddress".
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd MMM yyyy').format(now);
    final body = 'SOS at $timeStr, $dateStr\n$sosAddress';

    // Write the notification document — critical, abort on failure.
    final notifId = const Uuid().v4();
    try {
      await _firestore
          .collection('notifications')
          .doc(familyId)
          .collection('items')
          .doc(notifId)
          .set({
        'title': 'SOS Alert',
        'body': body,
        'type': 'sos',
        'childId': childId,
        'familyId': familyId,
        'alertId': alertId,
        'timestamp': sosTimestamp,
        'isRead': false,
        'sosTime': sosTimestamp,
        'sosLat': lat,
        'sosLng': lng,
        'sosAddress': sosAddress,
      });
    } catch (e) {
      print('sendSosAlert ERROR: $e');
      return false;
    }

    return true;
  }

  Stream<List<NotificationModel>> notificationsStream(String uid) {
    return _firestore
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NotificationModel.fromMap(doc.data(), doc.id))
            .toList())
        .handleError((e) {
      print('notificationsStream ERROR: $e');
      return <NotificationModel>[];
    });
  }

  Future<bool> markAsRead(String uid, String notifId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .doc(notifId)
          .update({'isRead': true});
      return true;
    } catch (e) {
      print('markAsRead ERROR: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead(String uid) async {
    try {
      final query = await _firestore
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return true;
    } catch (e) {
      print('markAllAsRead ERROR: $e');
      return false;
    }
  }

  // Returns a live stream of the latest active SOS alert for the family.
  // Emits null when no active alert exists, so callers can hide the popup.
  Stream<SosAlertModel?> unresolvedSosStream(String familyId) {
    print('[SVC-SOS-METHOD-ENTERED] familyId=$familyId');
    print('[SVC-SOS-SUB] familyId=$familyId filters: familyId=$familyId, status=unresolved');
    return _firestore
        .collection('sos_alerts')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'unresolved')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      print('[SVC-SOS-SNAP] docsCount=${snapshot.docs.length} firstId=${snapshot.docs.isNotEmpty ? snapshot.docs.first.id : "none"}');
      print('[SVC-SOS-MAP] docsCount=${snapshot.docs.length} '
          'firstStatus=${snapshot.docs.isNotEmpty ? snapshot.docs.first.data()["status"] : "n/a"} '
          'firstFamilyId=${snapshot.docs.isNotEmpty ? snapshot.docs.first.data()["familyId"] : "n/a"}');
      if (snapshot.docs.isEmpty) return null;
      try {
        final doc = snapshot.docs.first;
        // Merge document ID so SosAlertModel.fromMap() can populate alertId.
        final map = <String, dynamic>{...doc.data(), 'alertId': doc.id};
        return SosAlertModel.fromMap(map);
      } catch (e) {
        print('unresolvedSosStream parse error: $e');
        return null;
      }
    }).handleError((Object e) {
      print('unresolvedSosStream ERROR: $e');
      return null;
    });
  }

  // Marks a SOS alert document as resolved so it no longer appears in the stream.
  Future<bool> markSosResolved(String alertId) async {
    try {
      await _firestore
          .collection('sos_alerts')
          .doc(alertId)
          .update({'status': 'resolved'});
      return true;
    } catch (e) {
      print('markSosResolved ERROR: $e');
      return false;
    }
  }

  Future<bool> sendAlarmAlert({
    required String childId,
    required String familyId,
    required double lat,
    required double lng,
    required String childName,
  }) async {
    final alertId = const Uuid().v4();
    final now = DateTime.now();
    final alarmTimestamp = Timestamp.fromDate(now);

    // Write the alarm alert document first — critical, abort on failure.
    try {
      final dataMap = <String, dynamic>{
        'childId': childId,
        'familyId': familyId,
        'lat': lat,
        'lng': lng,
        'childName': childName,
        'timestamp': alarmTimestamp,
        'status': 'unresolved',
        'sosTime': alarmTimestamp,
        'sosLat': lat,
        'sosLng': lng,
      };
      await _firestore.collection('alarm_alerts').doc(alertId).set(dataMap);
    } catch (e) {
      print('sendAlarmAlert ERROR: $e');
      return false;
    }

    // Reverse-geocode the alarm coordinates to a human-readable address.
    // Falls back to raw coordinates so geocoding never blocks the alert.
    String alarmAddress;
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) throw Exception('empty placemarks');
      final p = placemarks.first;
      final parts = <String>[
        if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
        if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
        if (p.country != null && p.country!.isNotEmpty) p.country!,
      ];
      alarmAddress = parts.isNotEmpty
          ? parts.join(', ')
          : 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
    } catch (_) {
      alarmAddress = 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
    }

    // Stamp the resolved address onto the alarm_alerts document (best effort).
    try {
      await _firestore
          .collection('alarm_alerts')
          .doc(alertId)
          .update({'sosAddress': alarmAddress});
    } catch (e) {
      print('sendAlarmAlert alarmAddress update ERROR: $e');
    }

    // Compose the notification body: "<childName> needs you\nAlarm at HH:mm, dd MMM yyyy\naddress".
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('dd MMM yyyy').format(now);
    final body = '$childName needs you\nAlarm at $timeStr, $dateStr\n$alarmAddress';

    // Write the notification document — isolated; failure does not fail the alarm send.
    final notifId = const Uuid().v4();
    try {
      await _firestore
          .collection('notifications')
          .doc(familyId)
          .collection('items')
          .doc(notifId)
          .set({
        'title': 'Alarm Alert',
        'body': body,
        'type': 'alarm',
        'childId': childId,
        'familyId': familyId,
        'alertId': alertId,
        'timestamp': alarmTimestamp,
        'isRead': false,
        'sosTime': alarmTimestamp,
        'sosLat': lat,
        'sosLng': lng,
        'sosAddress': alarmAddress,
      });
    } catch (e) {
      print('sendAlarmAlert notification ERROR: $e');
    }

    return true;
  }

  // Returns a live stream of the latest active alarm alert for the family.
  // Emits null when no active alert exists, so callers can hide the popup.
  Stream<AlarmAlertModel?> unresolvedAlarmStream(String familyId) {
    return _firestore
        .collection('alarm_alerts')
        .where('familyId', isEqualTo: familyId)
        .where('status', isEqualTo: 'unresolved')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;
      try {
        final doc = snapshot.docs.first;
        // Merge document ID so AlarmAlertModel.fromMap() can populate alertId.
        final map = <String, dynamic>{...doc.data(), 'alertId': doc.id};
        return AlarmAlertModel.fromMap(map);
      } catch (e) {
        print('unresolvedAlarmStream parse error: $e');
        return null;
      }
    }).handleError((Object e) {
      print('unresolvedAlarmStream ERROR: $e');
      return null;
    });
  }

  // Marks an alarm alert document as resolved so it no longer appears in the stream.
  Future<bool> markAlarmResolved(String alertId) async {
    try {
      await _firestore
          .collection('alarm_alerts')
          .doc(alertId)
          .update({'status': 'resolved'});
      return true;
    } catch (e) {
      print('markAlarmResolved ERROR: $e');
      return false;
    }
  }
}
