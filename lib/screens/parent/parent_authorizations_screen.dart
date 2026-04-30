import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'parent_home_screen.dart';

// Android 13+ (API 33) replaced READ/WRITE_EXTERNAL_STORAGE with granular media permissions.
// Permission.storage auto-grants on API 33+ without a dialog, so we use Permission.photos instead.

class ParentAuthorizationsScreen extends StatefulWidget {
  const ParentAuthorizationsScreen({super.key});

  @override
  State<ParentAuthorizationsScreen> createState() =>
      _ParentAuthorizationsScreenState();
}

class _ParentAuthorizationsScreenState
    extends State<ParentAuthorizationsScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _cameraGranted = false;
  bool _storageGranted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  // Check permissions that were already granted before
  Future<void> _checkExistingPermissions() async {
    final location = await Permission.locationWhenInUse.isGranted;
    final notification = await Permission.notification.isGranted;
    final camera = await Permission.camera.isGranted;
    // On Android 13+ use photos permission; on older versions use storage
    final storage = await _checkStoragePermission();

    setState(() {
      _locationGranted = location;
      _notificationGranted = notification;
      _cameraGranted = camera;
      _storageGranted = storage;
    });
  }

  // Returns true only if the user explicitly granted storage/media access
  Future<bool> _checkStoragePermission() async {
    final photosStatus = await Permission.photos.isGranted;
    if (photosStatus) return true;
    // Fallback for devices where photos permission is not applicable
    final storageStatus = await Permission.storage.isGranted;
    return storageStatus;
  }

  Future<void> _requestLocationPermission() async {
    if (_locationGranted) return;

    final status = await Permission.locationWhenInUse.request();
    setState(() {
      _locationGranted = status.isGranted;
    });

    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Location');
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (_notificationGranted) return;

    final status = await Permission.notification.request();
    setState(() {
      _notificationGranted = status.isGranted;
    });

    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Notification');
    }
  }

  Future<void> _requestCameraPermission() async {
    if (_cameraGranted) return;

    final status = await Permission.camera.request();
    setState(() {
      _cameraGranted = status.isGranted;
    });

    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Camera');
    }
  }

  Future<void> _requestStoragePermission() async {
    if (_storageGranted) return;

    // Request photos permission (Android 13+); fall back to storage for older versions
    PermissionStatus status = await Permission.photos.request();
    if (status.isGranted) {
      setState(() => _storageGranted = true);
      return;
    }

    // Older Android: try the legacy storage permission
    final storageStatus = await Permission.storage.request();
    setState(() {
      _storageGranted = storageStatus.isGranted;
    });

    if (storageStatus.isPermanentlyDenied || status.isPermanentlyDenied) {
      _showSettingsDialog('Storage');
    }
  }

  // Show dialog to open app settings when permission is permanently denied
  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission was denied. Please enable it from app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  bool get _allPermissionsGranted {
    return _locationGranted && _notificationGranted;
  }

  void _continue() {
    if (_allPermissionsGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ParentHomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please grant Location and Notification permissions to continue',
          ),
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
                  color: const Color(0xFF2196F3).withValues(alpha: 0.1),
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
                    PermissionCard(
                      icon: Icons.location_on,
                      title: 'Location',
                      description: 'Track your child\'s real-time location',
                      isGranted: _locationGranted,
                      isRequired: true,
                      onTap: _requestLocationPermission,
                    ),

                    const SizedBox(height: 16),

                    PermissionCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      description: 'Receive alerts and safety notifications',
                      isGranted: _notificationGranted,
                      isRequired: true,
                      onTap: _requestNotificationPermission,
                    ),

                    const SizedBox(height: 16),

                    PermissionCard(
                      icon: Icons.camera_alt,
                      title: 'Camera',
                      description: 'Scan QR codes to add children',
                      isGranted: _cameraGranted,
                      isRequired: false,
                      onTap: _requestCameraPermission,
                    ),

                    const SizedBox(height: 16),

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
              color: Colors.black.withValues(alpha: 0.05),
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
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.1)
                    : const Color(0xFF2196F3).withValues(alpha: 0.1),
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
                            color: const Color(0xFFFF9800).withValues(alpha: 0.1),
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