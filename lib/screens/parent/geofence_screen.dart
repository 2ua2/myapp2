import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/geofence_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/geofence_service.dart';

// WARNING: GeofenceModel is missing activeDays, startTime, endTime fields.
// These are saved as extra Firestore fields and read back via _geofenceMetadata.
// TODO: add activeDays (List<int>), startTime (String?), endTime (String?) to GeofenceModel.

class GeofenceScreen extends StatefulWidget {
  final String childName;

  const GeofenceScreen({
    super.key,
    this.childName = 'name',
  });

  @override
  State<GeofenceScreen> createState() => _GeofenceScreenState();
}

class _GeofenceScreenState extends State<GeofenceScreen> {
  List<GeofenceModel> _geofences = [];
  // Stores extra Firestore fields not present in GeofenceModel, keyed by geofenceId.
  Map<String, Map<String, dynamic>> _geofenceMetadata = {};
  final GeofenceService _geofenceService = GeofenceService();
  bool _isLoading = false;
  bool _isSaving = false;

  double? _pickedLat;
  double? _pickedLng;

  // 0 = Monday … 6 = Sunday; empty list means active all week.
  List<int> _activeDays = [];
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();

  static const _dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadGeofences();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  // Reads raw Firestore documents so activeDays/startTime/endTime are captured
  // into _geofenceMetadata alongside the parsed GeofenceModel list.
  Future<void> _loadGeofences() async {
    final familyId = context.read<AuthProvider>().currentUser?.familyId;
    if (familyId == null) return;
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('geofences')
          .doc(familyId)
          .collection('geofences')
          .get();
      if (!mounted) return;
      final geofences = <GeofenceModel>[];
      final metadata = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        try {
          final model = GeofenceModel.fromMap(data);
          geofences.add(model);
          metadata[model.geofenceId] = {
            'activeDays': data['activeDays'],
            'startTime': data['startTime'],
            'endTime': data['endTime'],
          };
        } catch (_) {
          // Skip malformed documents.
        }
      }
      setState(() {
        _geofences = geofences;
        _geofenceMetadata = metadata;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Opens a full-screen map dialog. The user taps or drags a marker to pick a
  // location. The circle overlay reflects the selected radius in real time.
  // On confirm, _pickedLat/_pickedLng and the two text controllers are updated.
  Future<void> _showMapPicker() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;

    // Use last-known position for an instant camera start (no GPS wait).
    LatLng initialLatLng = const LatLng(24.7136, 46.6753);
    double initialZoom = 4;
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        initialLatLng = LatLng(last.latitude, last.longitude);
        initialZoom = 14;
      }
    } catch (_) {}

    if (!mounted) return;

    final initialRadius =
        (double.tryParse(_radiusController.text) ?? 100.0).clamp(10.0, 1000.0);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        LatLng markerPos = initialLatLng;
        double dialogRadius = initialRadius;
        late StateSetter setMapState;

        Set<Circle> buildCircles() => {
              Circle(
                circleId: const CircleId('preview'),
                center: markerPos,
                radius: dialogRadius,
                fillColor: const Color(0xFF2196F3).withValues(alpha: 0.2),
                strokeColor: const Color(0xFF2196F3),
                strokeWidth: 2,
              ),
            };

        Set<Marker> buildMarkers() => {
              Marker(
                markerId: const MarkerId('picked'),
                position: markerPos,
                draggable: true,
                onDragEnd: (newPos) => setMapState(() {
                  markerPos = newPos;
                  // Rebuild both sets so the circle tracks the dragged pin.
                }),
              ),
            };

        Set<Marker> markers = buildMarkers();
        Set<Circle> circles = buildCircles();

        return StatefulBuilder(
          builder: (ctx, setState) {
            setMapState = setState;
            return Dialog(
              insetPadding: EdgeInsets.zero,
              child: SizedBox(
                width: double.maxFinite,
                height: double.maxFinite,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: markerPos,
                        zoom: initialZoom,
                      ),
                      markers: markers,
                      circles: circles,
                      myLocationEnabled:
                          permission != LocationPermission.denied &&
                              permission !=
                                  LocationPermission.deniedForever,
                      myLocationButtonEnabled: true,
                      onTap: (latLng) => setMapState(() {
                        markerPos = latLng;
                        markers = buildMarkers();
                        circles = buildCircles();
                      }),
                    ),
                    // Bottom overlay: coordinates, radius slider, action buttons.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF2196F3),
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${markerPos.latitude.toStringAsFixed(5)}, '
                                  '${markerPos.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  'Radius: ${dialogRadius.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: dialogRadius,
                                    min: 10,
                                    max: 1000,
                                    divisions: 99,
                                    activeColor: const Color(0xFF2196F3),
                                    label:
                                        '${dialogRadius.toStringAsFixed(0)}m',
                                    onChanged: (val) => setMapState(() {
                                      dialogRadius = val;
                                      circles = buildCircles();
                                    }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      _pickedLat = markerPos.latitude;
                                      _pickedLng = markerPos.longitude;
                                      _locationController.text =
                                          '${markerPos.latitude.toStringAsFixed(5)}, '
                                          '${markerPos.longitude.toStringAsFixed(5)}';
                                      _radiusController.text =
                                          dialogRadius.toStringAsFixed(0);
                                      Navigator.pop(dialogContext);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF2196F3),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Confirm',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(GeofenceModel geofence) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Safe Zone'),
        content: Text('Delete "${geofence.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFF44336)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _geofenceService.deleteGeofence(
          geofence.familyId, geofence.geofenceId);
      if (!mounted) return;
      setState(() {
        _geofences.remove(geofence);
        _geofenceMetadata.remove(geofence.geofenceId);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete safe zone'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
    }
  }

  void _showAddGeofenceDialog() {
    _pickedLat = null;
    _pickedLng = null;
    _activeDays = [];
    _startTime = null;
    _endTime = null;
    _nameController.clear();
    _locationController.clear();
    _radiusController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext innerContext, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(innerContext).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.88,
                minChildSize: 0.5,
                maxChildSize: 0.97,
                builder: (context, scrollController) {
                  return Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBDBDBD),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Add New Safe Zone',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF212121),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Name ──────────────────────────────────────
                        const Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'e.g., Home, School',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Location (opens map picker) ────────────────
                        const Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _showMapPicker,
                          child: AbsorbPointer(
                            child: TextField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                hintText: 'Tap to open map and pin a location',
                                hintStyle: const TextStyle(
                                  color: Color(0xFF9E9E9E),
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF5F5F5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                suffixIcon: Container(
                                  margin: const EdgeInsets.all(8),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.map,
                                    color: Color(0xFF2196F3),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tap the field above to open the map. '
                                'Tap anywhere on the map to place the pin.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Radius ────────────────────────────────────
                        const Text(
                          'Radius (meters)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _radiusController,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: 'e.g., 100 (set by map slider)',
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Active Days ───────────────────────────────
                        const Text(
                          'Active Days',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(7, (i) {
                            final selected = _activeDays.contains(i);
                            return GestureDetector(
                              onTap: () => setModalState(() {
                                if (selected) {
                                  _activeDays.remove(i);
                                } else {
                                  _activeDays.add(i);
                                }
                              }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF2196F3)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _dayLabels[i],
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF212121),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Leave all unselected to apply every day',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Active Time ───────────────────────────────
                        const Text(
                          'Active Time',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF757575),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimeTile(
                                label: 'Start Time',
                                time: _startTime,
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: innerContext,
                                    initialTime: _startTime ??
                                        const TimeOfDay(hour: 8, minute: 0),
                                  );
                                  if (t != null) {
                                    setModalState(() => _startTime = t);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTimeTile(
                                label: 'End Time',
                                time: _endTime,
                                onTap: () async {
                                  final t = await showTimePicker(
                                    context: innerContext,
                                    initialTime: _endTime ??
                                        const TimeOfDay(hour: 17, minute: 0),
                                  );
                                  if (t != null) {
                                    setModalState(() => _endTime = t);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Leave both unset to apply all day',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ── Save Button ───────────────────────────────
                        ElevatedButton(
                          onPressed: () async {
                            if (_nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a name'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            if (_pickedLat == null || _pickedLng == null) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please tap the location field to set a location'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            final radius =
                                double.tryParse(_radiusController.text);
                            if (radius == null || radius <= 0) {
                              ScaffoldMessenger.of(dialogContext).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a valid radius'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                              return;
                            }

                            // Capture auth before pop — innerContext is stale after dismiss.
                            final auth = innerContext.read<AuthProvider>();
                            final familyId = auth.currentUser?.familyId;
                            if (familyId == null) return;

                            final geofence = GeofenceModel(
                              geofenceId: const Uuid().v4(),
                              familyId: familyId,
                              name: _nameController.text.trim(),
                              latitude: _pickedLat!,
                              longitude: _pickedLng!,
                              radius: radius,
                              isActive: true,
                              createdAt: DateTime.now(),
                            );

                            // Snapshot dialog-level state before pop.
                            final savedDays = List<int>.from(_activeDays);
                            final savedStart = _startTime != null
                                ? '${_startTime!.hour.toString().padLeft(2, '0')}:'
                                    '${_startTime!.minute.toString().padLeft(2, '0')}'
                                : null;
                            final savedEnd = _endTime != null
                                ? '${_endTime!.hour.toString().padLeft(2, '0')}:'
                                    '${_endTime!.minute.toString().padLeft(2, '0')}'
                                : null;

                            Navigator.pop(dialogContext);
                            setState(() => _isSaving = true);

                            try {
                              // TODO: add activeDays/startTime/endTime to GeofenceModel
                              // so saveGeofence() can include them without a direct write.
                              final extendedMap = geofence.toMap()
                                ..addAll({
                                  'activeDays': savedDays,
                                  'startTime': savedStart,
                                  'endTime': savedEnd,
                                });

                              await FirebaseFirestore.instance
                                  .collection('geofences')
                                  .doc(familyId)
                                  .collection('geofences')
                                  .doc(geofence.geofenceId)
                                  .set(extendedMap);

                              if (!mounted) return;
                              setState(() {
                                _geofences.add(geofence);
                                _geofenceMetadata[geofence.geofenceId] = {
                                  'activeDays': savedDays,
                                  'startTime': savedStart,
                                  'endTime': savedEnd,
                                };
                                _isSaving = false;
                              });
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Safe zone added successfully'),
                                  backgroundColor: Color(0xFF4CAF50),
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              setState(() => _isSaving = false);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to save safe zone'),
                                  backgroundColor: Color(0xFFF44336),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2196F3),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Save Safe Zone',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF757575),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTimeTile({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
  }) {
    final display = time != null
        ? '${time.hour.toString().padLeft(2, '0')}:'
            '${time.minute.toString().padLeft(2, '0')}'
        : 'Not set';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF757575),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: Color(0xFF757575)),
                const SizedBox(width: 6),
                Text(
                  display,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: time != null
                        ? const Color(0xFF212121)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDays(dynamic rawDays) {
    if (rawDays == null) return 'All week';
    final days = rawDays as List<dynamic>;
    if (days.isEmpty || days.length == 7) return 'All week';
    return days.map((d) => _dayLabels[d as int]).join(', ');
  }

  String _formatTimeRange(String? start, String? end) {
    if (start == null && end == null) return 'All day';
    return '${start ?? '--:--'} – ${end ?? '--:--'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF212121)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Geofence Settings',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Child Info Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2196F3),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2196F3),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.child_care,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.childName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_geofences.where((g) => g.isActive).length} active safe zones',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _geofences.any((g) => g.isActive)
                                  ? const Color(0xFF4CAF50)
                                  : Colors.grey,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _geofences.any((g) => g.isActive)
                                  ? 'Protected'
                                  : 'No Protection',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Safe Zones List
                    ..._geofences.asMap().entries.map((entry) {
                      final index = entry.key;
                      final geofence = entry.value;
                      final meta = _geofenceMetadata[geofence.geofenceId];
                      final daysText = _formatDays(meta?['activeDays']);
                      final timeText = _formatTimeRange(
                        meta?['startTime'] as String?,
                        meta?['endTime'] as String?,
                      );

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: geofence.isActive
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFE0E0E0),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2196F3)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF2196F3),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        geofence.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF212121),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              color: geofence.isActive
                                                  ? const Color(0xFF4CAF50)
                                                  : Colors.grey,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            geofence.isActive
                                                ? 'Active'
                                                : 'Inactive',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: geofence.isActive
                                                  ? const Color(0xFF4CAF50)
                                                  : Colors.grey,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Color(0xFFF44336),
                                  ),
                                  onPressed: () => _confirmDelete(geofence),
                                ),
                                // Use update instead of set to preserve activeDays/startTime/endTime.
                                Switch(
                                  value: geofence.isActive,
                                  onChanged: (value) async {
                                    final updated = GeofenceModel(
                                      geofenceId: geofence.geofenceId,
                                      familyId: geofence.familyId,
                                      name: geofence.name,
                                      latitude: geofence.latitude,
                                      longitude: geofence.longitude,
                                      radius: geofence.radius,
                                      isActive: value,
                                      createdAt: geofence.createdAt,
                                    );
                                    setState(
                                        () => _geofences[index] = updated);
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('geofences')
                                          .doc(geofence.familyId)
                                          .collection('geofences')
                                          .doc(geofence.geofenceId)
                                          .update({'isActive': value});
                                    } catch (e) {
                                      if (!mounted) return;
                                      setState(
                                          () => _geofences[index] = geofence);
                                    }
                                  },
                                  activeThumbColor: const Color(0xFF4CAF50),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                const Icon(Icons.place,
                                    size: 16, color: Color(0xFF757575)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${geofence.latitude.toStringAsFixed(5)}, '
                                    '${geofence.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF757575),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.radio_button_unchecked,
                                    size: 16, color: Color(0xFF757575)),
                                const SizedBox(width: 8),
                                Text(
                                  'Radius: ${geofence.radius.toStringAsFixed(0)}m',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF757575),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 16, color: Color(0xFF757575)),
                                const SizedBox(width: 8),
                                Text(
                                  daysText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.access_time,
                                    size: 16, color: Color(0xFF757575)),
                                const SizedBox(width: 8),
                                Text(
                                  timeText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF757575),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    // Add Safe Zone Button
                    GestureDetector(
                      onTap: _showAddGeofenceDialog,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF2196F3),
                            width: 2,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2196F3)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Color(0xFF2196F3),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Add Safe Zone',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2196F3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
    );
  }
}
