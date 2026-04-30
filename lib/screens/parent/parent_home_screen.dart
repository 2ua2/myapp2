import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'parent_profile_screen.dart';
import 'notification_screen.dart';
import 'child_info_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedChild = 'Ahmed';
  bool _hasNotifications = true;
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();
  bool _showMapTypeDropdown = false;
  String _selectedMapType = 'Standard';

  // Google Maps
  GoogleMapController? _mapController;
  MapType _currentMapType = MapType.normal;
  Set<Marker> _markers = {};

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
  }

  @override
  void dispose() {
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

      final latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('current_location'),
            position: latLng,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
        };
      });

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

  void _onLocatePressed() {
    _goToCurrentLocation();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.my_location, color: Colors.white),
            const SizedBox(width: 12),
            Text('Locating $_selectedChild on map...'),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onChildPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildInfoScreen(childName: _selectedChild),
      ),
    );
  }

  void _onSetRoutePressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.directions, color: Colors.white),
            const SizedBox(width: 12),
            Text('Setting route to $_selectedChild...'),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
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
                    onTap: () {
                      setState(() {
                        _showMapTypeDropdown = !_showMapTypeDropdown;
                      });
                    },
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
                        onTap: _onChildPressed,
                      ),
                      _buildBottomNavItem(
                        icon: Icons.directions,
                        onTap: _onSetRoutePressed,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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