import 'package:flutter/material.dart';
import 'parent_home_screen.dart';

class ParentAuthorizationsScreen extends StatefulWidget {
  const ParentAuthorizationsScreen({super.key});

  @override
  State<ParentAuthorizationsScreen> createState() => _ParentAuthorizationsScreenState();
}

class _ParentAuthorizationsScreenState extends State<ParentAuthorizationsScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _cameraGranted = false;
  bool _storageGranted = false;

  void _requestLocationPermission() {
    setState(() {
      _locationGranted = !_locationGranted;
    });
    print('Location permission: $_locationGranted');
    // TODO: Implement actual permission request
  }

  void _requestNotificationPermission() {
    setState(() {
      _notificationGranted = !_notificationGranted;
    });
    print('Notification permission: $_notificationGranted');
    // TODO: Implement actual permission request
  }

  void _requestCameraPermission() {
    setState(() {
      _cameraGranted = !_cameraGranted;
    });
    print('Camera permission: $_cameraGranted');
    // TODO: Implement actual permission request
  }

  void _requestStoragePermission() {
    setState(() {
      _storageGranted = !_storageGranted;
    });
    print('Storage permission: $_storageGranted');
    // TODO: Implement actual permission request
  }

  bool get _allPermissionsGranted {
    return _locationGranted && _notificationGranted;
  }

  void _continue() {
      if (_allPermissionsGranted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ParentHomeScreen(),
          ),
        );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant Location and Notification permissions to continue'),
          backgroundColor: Color(0xFFFF9800),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2196F3).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.security,
                  size: 50,
                  color: Color(0xFF2196F3),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Authorizations',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Grant permissions to track and protect your children',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 40),

              Expanded(
                child: ListView(
                  children: [
                    // Location Permission (Required)
                    PermissionCard(
                      icon: Icons.location_on,
                      title: 'Location',
                      description: 'Track your child\'s real-time location',
                      isGranted: _locationGranted,
                      isRequired: true,
                      onTap: _requestLocationPermission,
                    ),

                    const SizedBox(height: 16),

                    // Notification Permission (Required)
                    PermissionCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      description: 'Receive alerts and safety notifications',
                      isGranted: _notificationGranted,
                      isRequired: true,
                      onTap: _requestNotificationPermission,
                    ),

                    const SizedBox(height: 16),

                    // Camera Permission (Optional)
                    PermissionCard(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      description: 'Scan QR codes to add children',
                      isGranted: _cameraGranted,
                      isRequired: false,
                      onTap: _requestCameraPermission,
                    ),

                    const SizedBox(height: 16),

                    // Storage Permission (Optional)
                    PermissionCard(
                      icon: Icons.folder,
                      title: 'Storage',
                      description: 'Save location history and photos',
                      isGranted: _storageGranted,
                      isRequired: false,
                      onTap: _requestStoragePermission,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allPermissionsGranted
                        ? const Color(0xFF2196F3)
                        : const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// Permission Card Widget
class PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final bool isRequired;
  final VoidCallback onTap;

  const PermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.isRequired,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isGranted
                ? const Color(0xFF4CAF50)
                : const Color(0xFFBDBDBD),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isGranted
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isGranted
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                      if (isRequired) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF9800).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9800),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF757575),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Icon(
              isGranted ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isGranted
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFBDBDBD),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}