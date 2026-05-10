import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/geofence_model.dart';

class GeofenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Firestore path: geofences/{familyId}/geofences/{geofenceId}
  // The family document acts as a namespace; the subcollection holds each geofence.
  CollectionReference<Map<String, dynamic>> _geofencesRef(String familyId) {
    return _firestore
        .collection('geofences')
        .doc(familyId)
        .collection('geofences');
  }

  // Saves a geofence document to Firestore under the family's namespace.
  Future<void> saveGeofence(GeofenceModel geofence) async {
    try {
      await _geofencesRef(geofence.familyId)
          .doc(geofence.geofenceId)
          .set(geofence.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Returns all geofences for the given family. Returns [] on any error.
  Future<List<GeofenceModel>> getGeofences(String familyId) async {
    try {
      final snapshot = await _geofencesRef(familyId).get();
      return snapshot.docs
          .map((doc) => GeofenceModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('getGeofences error: $e');
      return [];
    }
  }

  // Deletes a single geofence document from Firestore.
  Future<void> deleteGeofence(String familyId, String geofenceId) async {
    try {
      await _geofencesRef(familyId).doc(geofenceId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Returns true if the given coordinates are within the geofence boundary.
  // Uses the Haversine formula to calculate the great-circle distance in meters.
  bool isInsideGeofence(GeofenceModel geofence, double lat, double lng) {
    const double R = 6371000.0;

    final double dLat = (geofence.latitude - lat) * (pi / 180.0);
    final double dLng = (geofence.longitude - lng) * (pi / 180.0);

    final double latRad = lat * (pi / 180.0);
    final double geofenceLatRad = geofence.latitude * (pi / 180.0);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(latRad) * cos(geofenceLatRad) * sin(dLng / 2) * sin(dLng / 2);
    final double c = 2.0 * atan2(sqrt(a), sqrt(1.0 - a));
    final double distance = R * c;

    return distance <= geofence.radius;
  }

  // Returns geofenceIds where the child is outside the geofence boundary.
  // An empty list means the child is inside all active geofences.
  Future<List<String>> checkGeofences(
      String familyId, double lat, double lng) async {
    try {
      final geofences = await getGeofences(familyId);
      // returns geofenceIds where child is outside
      return geofences
          .where((g) => !isInsideGeofence(g, lat, lng))
          .map((g) => g.geofenceId)
          .toList();
    } catch (e) {
      print('checkGeofences error: $e');
      return [];
    }
  }

  // Emits the current list of geofences for a family whenever Firestore changes.
  Stream<List<GeofenceModel>> geofenceStream(String familyId) {
    return _geofencesRef(familyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => GeofenceModel.fromMap(doc.data()))
            .toList())
        .handleError((e) => print('geofenceStream error: $e'));
  }
}
