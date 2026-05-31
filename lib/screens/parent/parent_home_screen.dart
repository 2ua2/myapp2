import 'dart:async';
import 'dart:math' show min, max;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../models/location_model.dart';
import '../../models/geofence_model.dart';
import '../../providers/auth_provider.dart';
import 'parent_profile_screen.dart';
import 'notification_screen.dart';
import 'child_info_screen.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/alarm_alert_model.dart';
import '../../models/sos_alert_model.dart';
import 'message_screen.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import '../../services/notification_service.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedChild = '';
  bool _hasNotifications = true;
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();
  bool _showMapTypeDropdown = false;
  String _selectedMapType = 'Standard';

  // Google Maps
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  Set<Marker> _markers = {};

  // Tracking service instance
  final LocationService _locationService = LocationService();

  // Child tracking
  StreamSubscription<LocationModel?>? _locationSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _childrenSub;
  StreamSubscription<Position>? _parentLocationSub;
  StreamSubscription<List<GeofenceModel>>? _geofenceSub;
  LatLng? _childLocation;
  LatLng? _parentLocation;
  String? _childId;

  // Derived tracking state — kept in state for future UI wiring
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  double? _distanceToChild;
  DateTime? _lastChildLocationUpdate;

  // Locate button toggle: true = next tap focuses child, false = next tap focuses parent.
  bool _focusOnChild = true;
  // Whether the parent-to-child route polyline is currently shown.
  bool _showRoute = true;
  // Current state index for the layers button 4-state cycle (0–3).
  int _layersState = 0;
  // Whether geofence circles are currently rendered.
  bool _showGeofences = true;
  // Last emitted geofence list; used to rebuild circles when visibility toggles.
  List<GeofenceModel> _lastGeofences = [];
  // Geofence center label markers; merged into _markers on every overlay rebuild.
  Set<Marker> _geofenceLabelMarkers = {};

  // Guards initial camera animation so only the first GPS fix re-centers the map.
  bool _initialCameraDone = false;

  // SOS alert popup overlay state.
  final NotificationService _notifService = NotificationService();
  StreamSubscription<SosAlertModel?>? _sosAlertSub;
  SosAlertModel? _activeSosAlert;
  bool _sosPopupVisible = false;
  // Persisted ID of the last alert shown — prevents re-display after dismiss.
  String? _sosAlertId;

  // Alarm alert popup overlay state.
  StreamSubscription<AlarmAlertModel?>? _alarmAlertSub;
  AlarmAlertModel? _activeAlarmAlert;
  bool _alarmPopupVisible = false;
  // Persisted ID of the last alarm shown — prevents re-display after dismiss.
  String? _alarmAlertId;

  static const CameraPosition _defaultPosition = CameraPosition(
    target: LatLng(33.3152, 44.3661),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _showSearchResults = _searchController.text.isNotEmpty;
      });
    });
    _initChildTracking();
    _startParentLocationStream();
    _startGeofenceStream();
    // Load persisted last-seen SOS ID first so the stream handler can compare
    // against it immediately on first emission.
    _loadLastSeenSosIdAndStartStream();
    _loadLastSeenAlarmIdAndStartStream();
  }

  @override
  void dispose() {
    _childrenSub?.cancel();
    _locationSubscription?.cancel();
    _parentLocationSub?.cancel();
    _geofenceSub?.cancel();
    _sosAlertSub?.cancel();
    _alarmAlertSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _goToCurrentLocation();
  }

  // Fetches real GPS position, places a blue marker, and animates the camera.
  // Falls back to _defaultPosition silently on any error.
  Future<void> _goToCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _fallbackToDefault();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _fallbackToDefault();
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _fallbackToDefault();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      // If the position stream already centered the camera, skip.
      if (_initialCameraDone) return;

      final latLng = LatLng(position.latitude, position.longitude);
      _initialCameraDone = true;

      await _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: latLng, zoom: 16),
        ),
      );
    } catch (_) {
      _fallbackToDefault();
    }
  }

  void _fallbackToDefault() {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(_defaultPosition),
    );
  }

  void _initChildTracking() {
    // Cancel any existing subscription before re-subscribing.
    _childrenSub?.cancel();
    _childrenSub = null;

    final familyId = context.read<AuthProvider>().currentUser?.familyId;
    if (familyId == null) return;

    _childrenSub = AuthService().childrenStream(familyId).listen(
      (children) {
        if (!mounted) return;
        if (children.isEmpty) {
          setState(() {
            _childId = null;
            _selectedChild = '';
          });
          _locationSubscription?.cancel();
          _locationSubscription = null;
          return;
        }
        final first = children.first;
        final newChildId = first['id'] as String?;
        final newName = first['childName'] as String? ?? '';
        print('[PARENT-LINKED] familyId=$familyId childId=$newChildId childName=$newName');
        // Capture whether the child doc changed before updating state.
        final childChanged = newChildId != _childId;
        // Always refresh cached values on every emission.
        setState(() {
          _childId = newChildId;
          _selectedChild = newName;
        });
        print('_initChildTracking updated: childId=$_childId name=$_selectedChild');
        // Restart location stream only when the child doc id changes.
        if (childChanged && newChildId != null) {
          _locationSubscription?.cancel();
          _locationSubscription = null;
          _startChildLocationStream(newChildId);
        }
      },
      onError: (e) => print('_initChildTracking stream error: $e'),
    );
  }

  // Subscribes to the child's latest location from the history subcollection.
  // Calls _updateMapOverlays on every new emission.
  void _startChildLocationStream(String childId) {
    _locationSubscription?.cancel();
    _locationSubscription = _locationService.childLocationStream(childId).listen(
      (location) {
        if (!mounted) return;
        print('[PARENT-LOC-EMIT] childId=$childId lat=${location?.latitude} lng=${location?.longitude} ts=${location?.timestamp}');
        if (location == null) return;
        _childLocation = LatLng(location.latitude, location.longitude);
        _lastChildLocationUpdate = location.timestamp;
        _updateMapOverlays();
      },
      onError: (e) {
        print('[PARENT-LOC-ERR] $e');
        print('_startChildLocationStream error: $e');
      },
    );
  }

  // Subscribes to the device GPS stream and updates the parent marker live.
  void _startParentLocationStream() {
    _parentLocationSub?.cancel();
    _parentLocationSub = _locationService.parentLocationStream().listen(
      (position) {
        if (!mounted) return;
        _parentLocation = LatLng(position.latitude, position.longitude);
        // Center the camera on the first GPS fix if _goToCurrentLocation()
        // has not already done so (e.g. GPS was slow during map creation).
        if (!_initialCameraDone) {
          _initialCameraDone = true;
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(_parentLocation!, 16),
          );
        }
        _updateMapOverlays();
      },
      onError: (e) => print('_startParentLocationStream error: $e'),
    );
  }

  // Subscribes to the family's geofence collection and rebuilds map circles.
  void _startGeofenceStream() {
    final familyId = context.read<AuthProvider>().currentUser?.familyId;
    if (familyId == null) return;
    _geofenceSub?.cancel();
    _geofenceSub = _locationService.geofenceStream(familyId).listen(
      (geofences) {
        if (!mounted) return;
        _lastGeofences = geofences;
        final newLabels = _showGeofences
            ? _buildGeofenceLabelMarkers(geofences)
            : <Marker>{};
        _geofenceLabelMarkers = newLabels;
        setState(() {
          _circles = _showGeofences ? _buildGeofenceCircles(geofences) : {};
          // Remove stale geofence label markers, then add the fresh set.
          // Parent and child markers (no 'geofence_label_' prefix) are untouched.
          _markers = _markers
              .where((m) => !m.markerId.value.startsWith('geofence_label_'))
              .toSet()
            ..addAll(newLabels);
        });
      },
      onError: (e) => print('_startGeofenceStream error: $e'),
    );
  }

  // Converts active geofence models into map Circle overlays.
  Set<Circle> _buildGeofenceCircles(List<GeofenceModel> geofences) {
    return geofences
        .where((g) => g.isActive)
        .map((g) => Circle(
              circleId: CircleId(g.geofenceId),
              center: LatLng(g.latitude, g.longitude),
              radius: g.radius,
              fillColor: Colors.green.withValues(alpha: 0.15),
              strokeColor: Colors.green,
              strokeWidth: 2,
            ))
        .toSet();
  }

  // Converts active geofence models into flat green label Markers at their centers.
  Set<Marker> _buildGeofenceLabelMarkers(List<GeofenceModel> geofences) {
    return geofences
        .where((g) => g.isActive)
        .map((g) => Marker(
              markerId: MarkerId('geofence_label_${g.geofenceId}'),
              position: LatLng(g.latitude, g.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
              infoWindow: InfoWindow(title: g.name),
              anchor: const Offset(0.5, 0.5),
              flat: true,
              zIndexInt: 1,
            ))
        .toSet();
  }

  // Rebuilds markers, route polyline, and distance from current position state.
  // Called whenever parent or child location changes.
  void _updateMapOverlays() {
    final newMarkers = <Marker>{};
    final newPolylines = <Polyline>{};
    double? newDistance;

    if (_parentLocation != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('parent_location'),
        position: _parentLocation!,
        infoWindow: const InfoWindow(title: 'You'),
        // Bug 4: hueAzure distinguishes parent from child (hueRed) while
        // keeping the same defaultMarkerWithHue visual style.
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      ));
    }

    if (_childLocation != null) {
      final childName = _selectedChild.isNotEmpty ? _selectedChild : 'Child';

      newMarkers.add(Marker(
        markerId: const MarkerId('child_location'),
        position: _childLocation!,
        infoWindow: InfoWindow(title: childName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

    }

    if (_parentLocation != null && _childLocation != null) {
      if (_showRoute) {
        newPolylines.add(Polyline(
          polylineId: const PolylineId('parent_child_route'),
          points: [_parentLocation!, _childLocation!],
          color: const Color(0xFFFF9800),
          width: 5,
          geodesic: true,
        ));
      }
      newDistance = _locationService.distanceBetween(
        _parentLocation!,
        _childLocation!,
      );
    }

    setState(() {
      // Merge geofence label markers so position updates never wipe them.
      _markers = {...newMarkers, ..._geofenceLabelMarkers};
      _polylines = newPolylines;
      _distanceToChild = newDistance;
    });

    // Re-show the child name InfoWindow after every location update so it
    // stays visible without requiring the user to tap the label marker.
    if (_childLocation != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController?.showMarkerInfoWindow(
            const MarkerId('child_location'),
          );
        }
      });
    }
  }

  // Animates the camera to show both parent and child markers with padding.
  void _showBothMarkers() {
    if (_parentLocation == null || _childLocation == null) return;
    final minLat = min(_parentLocation!.latitude, _childLocation!.latitude);
    final maxLat = max(_parentLocation!.latitude, _childLocation!.latitude);
    final minLng = min(_parentLocation!.longitude, _childLocation!.longitude);
    final maxLng = max(_parentLocation!.longitude, _childLocation!.longitude);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80.0,
      ),
    );
  }

  // Toggles camera focus between child and parent on each tap.
  // Does nothing silently when the target location is not yet available.
  void _onLocatePressed() {
    if (_focusOnChild) {
      if (_childLocation == null) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_childLocation!, 16),
      );
      setState(() => _focusOnChild = false);
    } else {
      if (_parentLocation == null) return;
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_parentLocation!, 16),
      );
      setState(() => _focusOnChild = true);
    }
  }

  Future<void> _onChildPressed() async {
    // Stream has already delivered a child — use cached values immediately.
    if (_childId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChildInfoScreen(
            childName: _selectedChild,
            childId: _childId!,
          ),
        ),
      ).then((_) { if (mounted) _initChildTracking(); });
      return;
    }

    // Stream hasn't emitted yet (race condition) — fetch once from Firestore.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('families')
          .doc(user.uid)
          .collection('children')
          .where('status', isEqualTo: 'linked')
          .limit(1)
          .get();

      if (!mounted) return;

      if (snapshot.docs.isEmpty) {
        // Truly no linked child — open empty state.
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ChildInfoScreen(
              childName: '',
              childId: '',
            ),
          ),
        ).then((_) { if (mounted) _initChildTracking(); });
        return;
      }

      final doc = snapshot.docs.first;
      final childId = doc.id;
      final childName = doc.data()['childName'] as String? ?? '';

      // Cache fetched values so next tap skips the Firestore round-trip.
      setState(() {
        _childId = childId;
        _selectedChild = childName;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChildInfoScreen(
            childName: childName,
            childId: childId,
          ),
        ),
      ).then((_) { if (mounted) _initChildTracking(); });
    } catch (e) {
      print('_onChildPressed fetch error: $e');
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChildInfoScreen(
            childName: '',
            childId: '',
          ),
        ),
      ).then((_) { if (mounted) _initChildTracking(); });
    }
  }

  // Short tap: toggles the parent-to-child route polyline on/off.
  // _updateMapOverlays() reads _showRoute and rebuilds _polylines consistently,
  // so there is no duplicated polyline construction here.
  void _onSetRoutePressed() {
    _showRoute = !_showRoute;
    _updateMapOverlays();
  }

  // Cycles the map through 4 states: normal+geofences, satellite+geofences,
  // terrain+geofences, normal+no-geofences, then back to state 0.
  void _onLayersPressed() {
    _layersState = (_layersState + 1) % 4;
    MapType newMapType;
    bool newShowGeofences;
    switch (_layersState) {
      case 1:
        newMapType = MapType.satellite;
        newShowGeofences = true;
        break;
      case 2:
        newMapType = MapType.terrain;
        newShowGeofences = true;
        break;
      case 3:
        newMapType = MapType.normal;
        newShowGeofences = false;
        break;
      default: // case 0
        newMapType = MapType.normal;
        newShowGeofences = true;
    }
    final newLabels = newShowGeofences
        ? _buildGeofenceLabelMarkers(_lastGeofences)
        : <Marker>{};
    _geofenceLabelMarkers = newLabels;
    setState(() {
      _currentMapType = newMapType;
      _showGeofences = newShowGeofences;
      _circles = newShowGeofences ? _buildGeofenceCircles(_lastGeofences) : {};
      // Remove stale geofence label markers, then add the fresh set.
      _markers = _markers
          .where((m) => !m.markerId.value.startsWith('geofence_label_'))
          .toSet()
        ..addAll(newLabels);
    });
  }

  void _onNotificationPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationScreen(),
      ),
    );
  }

  void _changeMapType(String label) {
    MapType newType;
    switch (label) {
      case 'Satellite':
        newType = MapType.satellite;
        break;
      case 'Terrain':
        newType = MapType.terrain;
        break;
      default:
        newType = MapType.normal;
    }
    setState(() {
      _selectedMapType = label;
      _currentMapType = newType;
      _showMapTypeDropdown = false;
    });
  }

  // Reads the last-seen SOS alert ID from SharedPreferences, then subscribes
  // to the real-time stream. Called once from initState.
  Future<void> _loadLastSeenSosIdAndStartStream() async {
    print('[PARENT-SOS-LOAD-CALLED]');
    try {
      final prefs = await SharedPreferences.getInstance();
      _sosAlertId = prefs.getString('last_seen_sos_id');
    } catch (e) {
      print('_loadLastSeenSosIdAndStartStream prefs read error: $e');
    }
    print('[PARENT-SOS-LASTSEEN] id=$_sosAlertId');
    if (!mounted) return;
    _startSosAlertStream();
  }

  // Subscribes to the latest active SOS alert for the current family.
  void _startSosAlertStream() {
    print('[PARENT-SOS-START-CALLED] familyId=${context.read<AuthProvider>().currentUser?.familyId}');
    final familyId = context.read<AuthProvider>().currentUser?.familyId;
    if (familyId == null) return;
    print('[PARENT-SOS-START-SUBSCRIBING] familyId=$familyId');
    _sosAlertSub?.cancel();
    _sosAlertSub = _notifService.unresolvedSosStream(familyId).listen(
      (alert) {
        if (!mounted) return;
        print('[PARENT-SOS-EMIT] alertId=${alert?.alertId} status=${alert == null ? "null" : (alert.alertId == _sosAlertId ? "existing" : "new")} cachedSosId=$_sosAlertId');
        if (alert == null) {
          setState(() {
            _sosPopupVisible = false;
            _activeSosAlert = null;
          });
          return;
        }
        // Only show the popup for alerts the parent has not yet seen.
        if (alert.alertId != _sosAlertId) {
          setState(() {
            _activeSosAlert = alert;
            _sosAlertId = alert.alertId;
            _sosPopupVisible = true;
          });
        }
      },
      onError: (e) {
        print('[PARENT-SOS-ERR] $e');
        print('_startSosAlertStream error: $e');
      },
    );
  }

  // Marks the SOS alert resolved in Firestore and persists its ID so it is
  // never re-shown after a hot-reload or app restart.
  Future<void> _resolveAndPersistSosAlert(String alertId) async {
    try {
      await _notifService.markSosResolved(alertId);
    } catch (e) {
      print('_resolveAndPersistSosAlert markSosResolved error: $e');
    }
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_seen_sos_id', alertId);
    } catch (e) {
      print('_resolveAndPersistSosAlert prefs write error: $e');
    }
  }

  // Respond: animate camera to SOS location, enable route polyline, hide popup.
  void _onSosRespond() {
    final alert = _activeSosAlert;
    if (alert == null) return;
    final sosLatLng = LatLng(alert.latitude, alert.longitude);
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(sosLatLng, 17),
    );
    setState(() {
      _showRoute = true;
      _sosPopupVisible = false;
      if (_parentLocation != null) {
        _polylines = {
          Polyline(
            polylineId: const PolylineId('parent_child_route'),
            points: [_parentLocation!, sosLatLng],
            color: const Color(0xFFFF9800),
            width: 5,
            geodesic: true,
          ),
        };
      }
    });
    _resolveAndPersistSosAlert(alert.alertId);
  }

  // Dismiss: hide popup only — does not change camera or route.
  void _onSosDismiss() {
    final alert = _activeSosAlert;
    if (alert == null) return;
    setState(() => _sosPopupVisible = false);
    _resolveAndPersistSosAlert(alert.alertId);
  }

  // Builds the full-screen SOS overlay: dimmed backdrop + animated popup card.
  Widget _buildSosPopup() {
    final alert = _activeSosAlert!;
    final address =
        (alert.sosAddress != null && alert.sosAddress!.isNotEmpty)
            ? alert.sosAddress!
            : 'Lat: ${alert.latitude.toStringAsFixed(5)}, '
                'Lng: ${alert.longitude.toStringAsFixed(5)}';
    final timeStr = DateFormat('HH:mm').format(alert.timestamp);
    final dateStr = DateFormat('dd MMM yyyy').format(alert.timestamp);
    final cardWidth = MediaQuery.of(context).size.width * 0.85;

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 0.4),
        duration: const Duration(milliseconds: 250),
        builder: (_, opacity, child) => ColoredBox(
          color: Colors.black.withValues(alpha: opacity),
          child: child,
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: _buildSosCard(alert, address, timeStr, dateStr, cardWidth),
          ),
        ),
      ),
    );
  }

  // Builds the white card widget shown inside the SOS overlay.
  Widget _buildSosCard(
    SosAlertModel alert,
    String address,
    String timeStr,
    String dateStr,
    double cardWidth,
  ) {
    return SizedBox(
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Red top accent — top corners clipped by parent ClipRRect.
              Container(height: 6, color: const Color(0xFFE53935)),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFE53935),
                      size: 64,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'YOUR CHILD IS IN DANGER!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE53935),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${alert.childName} needs help right now.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$timeStr - $dateStr',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        OutlinedButton(
                          onPressed: _onSosDismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black54,
                            side: const BorderSide(color: Colors.black26),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('DISMISS'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _onSosRespond,
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('RESPOND'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reads the last-seen alarm alert ID from SharedPreferences, then subscribes
  // to the real-time stream. Called once from initState.
  Future<void> _loadLastSeenAlarmIdAndStartStream() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _alarmAlertId = prefs.getString('last_seen_alarm_id');
    } catch (e) {
      print('_loadLastSeenAlarmIdAndStartStream prefs read error: $e');
    }
    if (!mounted) return;
    _startAlarmAlertStream();
  }

  // Subscribes to the latest active alarm alert for the current family.
  void _startAlarmAlertStream() {
    final familyId = context.read<AuthProvider>().currentUser?.familyId;
    if (familyId == null) return;
    _alarmAlertSub?.cancel();
    _alarmAlertSub = _notifService.unresolvedAlarmStream(familyId).listen(
      (alert) {
        if (!mounted) return;
        if (alert == null) {
          setState(() {
            _alarmPopupVisible = false;
            _activeAlarmAlert = null;
          });
          return;
        }
        // Only show the popup for alerts the parent has not yet seen.
        if (alert.alertId != _alarmAlertId) {
          setState(() {
            _activeAlarmAlert = alert;
            _alarmAlertId = alert.alertId;
            _alarmPopupVisible = true;
          });
        }
      },
      onError: (e) => print('_startAlarmAlertStream error: $e'),
    );
  }

  // Marks the alarm alert resolved in Firestore and persists its ID so it is
  // never re-shown after a hot-reload or app restart.
  Future<void> _resolveAndPersistAlarmAlert(String alertId) async {
    try {
      await _notifService.markAlarmResolved(alertId);
    } catch (e) {
      print('_resolveAndPersistAlarmAlert markAlarmResolved error: $e');
    }
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_seen_alarm_id', alertId);
    } catch (e) {
      print('_resolveAndPersistAlarmAlert prefs write error: $e');
    }
  }

  // Call back: placeholder — shows a SnackBar, does NOT close or resolve the alert.
  void _onAlarmCallBack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call back not available yet.')),
    );
  }

  // Send text: close popup, resolve alert, then navigate to MessageScreen.
  void _onAlarmSendText() {
    final alert = _activeAlarmAlert;
    if (alert == null) return;
    setState(() => _alarmPopupVisible = false);
    _resolveAndPersistAlarmAlert(alert.alertId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final parentUid = user.uid;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageScreen(
          chatId: '${parentUid}_${alert.childId}',
          senderId: parentUid,
          recipientId: alert.childId,
          childName: alert.childName,
          senderRole: 'parent',
        ),
      ),
    );
  }

  // Dismiss: hide popup, resolve alert, persist ID.
  void _onAlarmDismiss() {
    final alert = _activeAlarmAlert;
    if (alert == null) return;
    setState(() => _alarmPopupVisible = false);
    _resolveAndPersistAlarmAlert(alert.alertId);
  }

  // Builds the full-screen alarm overlay: dimmed backdrop + animated popup card.
  Widget _buildAlarmPopup() {
    final alert = _activeAlarmAlert!;
    final address =
        (alert.sosAddress != null && alert.sosAddress!.isNotEmpty)
            ? alert.sosAddress!
            : 'Lat: ${alert.latitude.toStringAsFixed(5)}, '
                'Lng: ${alert.longitude.toStringAsFixed(5)}';
    final timeStr = DateFormat('HH:mm').format(alert.timestamp);
    final dateStr = DateFormat('dd MMM yyyy').format(alert.timestamp);
    final cardWidth = MediaQuery.of(context).size.width * 0.85;

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 0.4),
        duration: const Duration(milliseconds: 250),
        builder: (_, opacity, child) => ColoredBox(
          color: Colors.black.withValues(alpha: opacity),
          child: child,
        ),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (_, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: _buildAlarmCard(alert, address, timeStr, dateStr, cardWidth),
          ),
        ),
      ),
    );
  }

  // Builds the white card widget shown inside the alarm overlay.
  Widget _buildAlarmCard(
    AlarmAlertModel alert,
    String address,
    String timeStr,
    String dateStr,
    double cardWidth,
  ) {
    const accentColor = Color(0xFFFF9800);
    return SizedBox(
      width: cardWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Orange/amber top accent — top corners clipped by parent ClipRRect.
              Container(height: 6, color: accentColor),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.notifications_active,
                          color: accentColor,
                          size: 64,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'YOUR CHILD NEEDS YOU',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${alert.childName} is trying to reach you.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          address,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$timeStr - $dateStr',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Disabled-looking but still tappable — placeholder action.
                            Opacity(
                              opacity: 0.45,
                              child: OutlinedButton(
                                onPressed: _onAlarmCallBack,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black54,
                                  side: const BorderSide(color: Colors.black26),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('CALL BACK'),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _onAlarmSendText,
                              icon: const Icon(Icons.message, size: 18),
                              label: const Text('SEND TEXT'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Close (X) button — top-right of card content area.
                    Positioned(
                      top: -12,
                      right: -12,
                      child: IconButton(
                        onPressed: _onAlarmDismiss,
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          if (_showMapTypeDropdown) {
            setState(() => _showMapTypeDropdown = false);
          }
          if (_showSearchResults) {
            _searchFocusNode.unfocus();
          }
        },
        child: Stack(
          children: [
            // Google Map
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: _defaultPosition,
              mapType: _currentMapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: true,
              markers: _markers,
              polylines: _polylines,
              circles: _circles,
            ),

            // Top Bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ParentProfileScreen(),
                                ),
                              );
                            },
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2196F3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 14),
                                  const Icon(
                                    Icons.search,
                                    color: Color(0xFF757575),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      decoration: const InputDecoration(
                                        hintText: 'Search location...',
                                        hintStyle: TextStyle(
                                          color: Color(0xFF9E9E9E),
                                          fontSize: 14,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                                      ),
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Color(0xFF757575),
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        _searchFocusNode.unfocus();
                                      },
                                    )
                                  else
                                    const SizedBox(width: 10),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          GestureDetector(
                            onTap: _onNotificationPressed,
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFE0E0E0)),
                              ),
                              child: Stack(
                                children: [
                                  const Center(
                                    child: Icon(
                                      Icons.notifications,
                                      color: Color(0xFF2196F3),
                                      size: 22,
                                    ),
                                  ),
                                  if (_hasNotifications)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF44336),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        ],
                      ),
                    ),

                    if (_showSearchResults)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_off, size: 24, color: Colors.grey[400]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No results, try something else...',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Map Layers Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: _onLayersPressed,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _showMapTypeDropdown
                            ? const Color(0xFF2196F3)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.layers,
                        color: _showMapTypeDropdown
                            ? Colors.white
                            : const Color(0xFF757575),
                        size: 24,
                      ),
                    ),
                  ),

                  if (_showMapTypeDropdown)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildMapTypeOption(
                            icon: Icons.map_outlined,
                            label: 'Standard',
                            isSelected: _selectedMapType == 'Standard',
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _buildMapTypeOption(
                            icon: Icons.satellite_alt,
                            label: 'Satellite',
                            isSelected: _selectedMapType == 'Satellite',
                          ),
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          _buildMapTypeOption(
                            icon: Icons.terrain,
                            label: 'Terrain',
                            isSelected: _selectedMapType == 'Terrain',
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildBottomNavItem(
                        icon: Icons.my_location,
                        onTap: _onLocatePressed,
                      ),
                      _buildBottomNavItem(
                        icon: Icons.child_care,
                        onTap: () { _onChildPressed(); },
                      ),
                      GestureDetector(
                        onLongPress: _showBothMarkers,
                        child: _buildBottomNavItem(
                          icon: Icons.directions,
                          onTap: _onSetRoutePressed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Alarm popup — rendered before SOS so SOS stacks on top when both are active.
            if (_alarmPopupVisible && _activeAlarmAlert != null) _buildAlarmPopup(),
            // SOS alert popup overlay — sits on top of all other map widgets.
            if (_sosPopupVisible && _activeSosAlert != null) _buildSosPopup(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 60,
        height: 60,
        alignment: Alignment.center,
        child: Icon(
          icon,
          color: const Color(0xFF757575),
          size: 28,
        ),
      ),
    );
  }

  Widget _buildMapTypeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _changeMapType(label),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF757575),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF2196F3) : const Color(0xFF212121),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, color: Color(0xFF2196F3), size: 18),
          ],
        ),
      ),
    );
  }
}