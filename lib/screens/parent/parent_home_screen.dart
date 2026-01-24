import 'package:flutter/material.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _showLocationHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Location History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildLocationHistoryItem(
                        'Home',
                        '123 Main Street, Springfield',
                        '2 mins ago',
                        Icons.home,
                        const Color(0xFF4CAF50),
                      ),
                      _buildLocationHistoryItem(
                        'School',
                        'Greenwood Elementary, Oak Avenue',
                        '3 hours ago',
                        Icons.school,
                        const Color(0xFF2196F3),
                      ),
                      _buildLocationHistoryItem(
                        'Park',
                        'Central Park, Elm Street',
                        '5 hours ago',
                        Icons.park,
                        const Color(0xFF4CAF50),
                      ),
                      _buildLocationHistoryItem(
                        'Friend\'s House',
                        '456 Oak Road, Springfield',
                        'Yesterday at 4:30 PM',
                        Icons.person,
                        const Color(0xFFFF9800),
                      ),
                      _buildLocationHistoryItem(
                        'Library',
                        'City Library, Pine Street',
                        'Yesterday at 2:00 PM',
                        Icons.local_library,
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map Area
          Container(
            color: const Color(0xFFE0E0E0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map,
                    size: 100,
                    color: Colors.grey[400],
                  ),
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
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    GestureDetector(
                      onTap: () => print('Profile'),
                      child: Container(
                        width: 40,
                        height: 40,
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.search, color: Color(0xFF757575), size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: const InputDecoration(
                                  hintText: 'Search location...',
                                  hintStyle: TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.mic, color: Color(0xFF757575), size: 20),
                              onPressed: () => print('Voice'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => print('Notifications'),
                      child: Stack(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE0E0E0)),
                            ),
                            child: const Icon(Icons.notifications, color: Color(0xFF2196F3), size: 24),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
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
                  ],
                ),
              ),
            ),
          ),

          // Map Type Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.layers, color: Color(0xFF2196F3), size: 24),
                onPressed: () => print('Map type'),
              ),
            ),
          ),

          // Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.33,
            minChildSize: 0.33,
            maxChildSize: 0.67,
            snap: true,
            snapSizes: const [0.33, 0.67],
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    // Drag Handle
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFBDBDBD),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Child Profile (Expandable)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          // Basic Info
                          Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: const Icon(Icons.child_care, color: Colors.white, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'name',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 16, color: Color(0xFF4CAF50)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            'null',
                                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2196F3).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.message, color: Color(0xFF2196F3), size: 22),
                                  onPressed: () => print('Message'),
                                ),
                              ),
                            ],
                          ),

                          // Additional Info
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildInfoRow(Icons.cake, 'Age', 'xx'),
                                const Divider(height: 24),
                                _buildInfoRow(Icons.phone, 'Phone Number', 'xxx-xxxx'),
                                const Divider(height: 24),
                                _buildInfoRow(Icons.school, 'School', 'null'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Parent Controls
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Parent Controls',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF212121),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Row 1: SOS (Circle - Center)
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF44336),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF44336).withOpacity(0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => print('SOS'),
                                  borderRadius: BorderRadius.circular(50),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.warning, color: Colors.white, size: 40),
                                      SizedBox(height: 4),
                                      Text(
                                        'SOS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Row 2: Call + Alarm
                          Row(
                            children: [
                              Expanded(
                                child: _buildSquareControl(
                                  icon: Icons.call,
                                  label: 'Call',
                                  color: const Color(0xFF4CAF50),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildSquareControl(
                                  icon: Icons.notifications_active,
                                  label: 'Alarm',
                                  color: const Color(0xFFFF9800),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Row 3: Geofence + Location History
                          Row(
                            children: [
                              Expanded(
                                child: _buildSquareControl(
                                  icon: Icons.location_city,
                                  label: 'Geofence',
                                  color: const Color(0xFF2196F3),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showLocationHistory,
                                  child: Container(
                                    height: 90,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9C27B0).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF9C27B0),
                                        width: 2,
                                      ),
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.history, color: Color(0xFF9C27B0), size: 32),
                                        SizedBox(height: 8),
                                        Text(
                                          'History',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF9C27B0),
                                          ),
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

                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF2196F3), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121),
          ),
        ),
      ],
    );
  }

  Widget _buildSquareControl({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => print('$label tapped'),
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHistoryItem(
      String title,
      String address,
      String time,
      IconData icon,
      Color color,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF757575)),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
          ),
        ],
      ),
    );
  }
}