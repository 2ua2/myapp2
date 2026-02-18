import 'package:flutter/material.dart';
import 'parent_profile_screen.dart';
import 'notification_screen.dart';
import 'message_screen.dart';
import 'geofence_screen.dart';
import 'child_info_screen.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedChild = 'Ahmed';
  bool _showSearchResults = false;
  final FocusNode _searchFocusNode = FocusNode();
  bool _showMapTypeDropdown = false;
  String _selectedMapType = 'Standard';

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
    super.dispose();
  }

  void _onCallPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.phone, color: Colors.white),
            const SizedBox(width: 12),
            Text('Calling $_selectedChild...'),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onAlarmPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.white),
            SizedBox(width: 12),
            Text('Alarm activated'),
          ],
        ),
        backgroundColor: Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onMessagePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(childName: _selectedChild),
      ),
    );
  }

  void _onChildPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildInfoScreen(
          childName: _selectedChild,
        ),
      ),
    );
  }

  void _onGeofencePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceScreen(childName: _selectedChild),
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
            // Map Area
            Container(
              color: const Color(0xFFE0E0E0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 100, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'Map View',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
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
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Profile Icon - Left
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

                          // Search Bar - Center
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

                          // Map Settings Dropdown - Right
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _showMapTypeDropdown = !_showMapTypeDropdown;
                                  });
                                },
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: _showMapTypeDropdown
                                        ? const Color(0xFF2196F3)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.layers,
                                    color: _showMapTypeDropdown
                                        ? Colors.white
                                        : const Color(0xFF2196F3),
                                    size: 22,
                                  ),
                                ),
                              ),

                              // Dropdown Menu
                              if (_showMapTypeDropdown)
                                Positioned(
                                  top: 50,
                                  right: 0,
                                  child: Material(
                                    elevation: 8,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      width: 160,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.1),
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
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Search Results Dropdown
                    if (_showSearchResults)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
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
            // Bottom Navigation Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Child
                      _buildBottomNavItem(
                        icon: Icons.child_care,
                        onTap: _onChildPressed,
                      ),
                      // Call
                      _buildBottomNavItem(
                        icon: Icons.phone,
                        onTap: _onCallPressed,
                      ),
                      // Message
                      _buildBottomNavItem(
                        icon: Icons.message,
                        onTap: _onMessagePressed,
                      ),
                      // Geofence
                      _buildBottomNavItem(
                        icon: Icons.location_on,
                        onTap: _onGeofencePressed,
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
      onTap: () {
        setState(() {
          _selectedMapType = label;
          _showMapTypeDropdown = false;
        });
        print('Map type changed to: $label');
      },
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