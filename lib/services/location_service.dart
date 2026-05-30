import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/location_model.dart';
import '../models/geofence_model.dart';

class LocationService {
  // Continuous GPS stream for the parent device.
  // Emits on every 10-metre move; the platform may also emit on time intervals.
  Stream<Position> parentLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  // Latest child location from /locations/{childId}/history as a live stream.
  // Queries the subcollection ordered by timestamp desc, limit 1.
  // Returns null when the subcollection is empty or the document cannot be parsed.
  Stream<LocationModel?> childLocationStream(String childId) {
    print('[SVC-CHILDLOC-SUB] path=locations/$childId/history orderBy=timestamp desc limit=1');
    return FirebaseFirestore.instance
        .collection('locations')
        .doc(childId)
        .collection('history')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      print('[SVC-CHILDLOC-SNAP] docsCount=${snapshot.docs.length} firstId=${snapshot.docs.isNotEmpty ? snapshot.docs.first.id : "none"}');
      if (snapshot.docs.isEmpty) return null;
      try {
        final doc = snapshot.docs.first;
        // Merge doc ID as locationId and childId so fromMap() never throws on
        // documents written with the minimal {lat, lng, timestamp} schema.
        return LocationModel.fromMap({
          ...doc.data(),
          'locationId': doc.id,
          'childId': childId,
        });
      } catch (e) {
        print('LocationService childLocationStream parse error: $e');
        return null;
      }
    });
  }

  // Writes one location document for the child into /locations/{childId}/history.
  // Uses Firestore auto-generated doc IDs so no uuid dependency is needed.
  Future<void> writeChildLocation(
    String childId,
    String familyId,
    double lat,
    double lng,
  ) async {
    await FirebaseFirestore.instance
        .collection('locations')
        .doc(childId)
        .collection('history')
        .add({
      'childId': childId,
      'familyId': familyId,
      'latitude': lat,
      'longitude': lng,
      'timestamp': Timestamp.now(),
    });
  }

  // Live stream of all active geofence zones for a family.
  // Path: /geofences/{familyId}/geofences
  Stream<List<GeofenceModel>> geofenceStream(String familyId) {
    return FirebaseFirestore.instance
        .collection('geofences')
        .doc(familyId)
        .collection('geofences')
        .snapshots()
        .map((snapshot) {
      final zones = <GeofenceModel>[];
      for (final doc in snapshot.docs) {
        try {
          zones.add(GeofenceModel.fromMap(doc.data()));
        } catch (e) {
          print('LocationService geofenceStream parse error on ${doc.id}: $e');
        }
      }
      return zones;
    }).handleError((Object e) {
      print('LocationService geofenceStream stream error: $e');
      return <GeofenceModel>[];
    });
  }

  // Straight-line distance in metres between two map coordinates.
  double distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }
}
