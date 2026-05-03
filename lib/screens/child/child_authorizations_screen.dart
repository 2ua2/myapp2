import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'child_home_screen.dart';

class ChildAuthorizationsScreen extends StatefulWidget {
  const ChildAuthorizationsScreen({super.key});

  @override
  State<ChildAuthorizationsScreen> createState() => _ChildAuthorizationsScreenState();
}

class _ChildAuthorizationsScreenState extends State<ChildAuthorizationsScreen> {
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _microphoneGranted = false;
  bool _flashlightGranted = false;

  @override
  void initState() {
    super.initState();
    _checkExistingPermissions();
  }

  // Pre-fill booleans for permissions already granted in a prior session.
  Future<void> _checkExistingPermissions() async {
    // Location is considered granted only when background access is confirmed.
    final locationAlways = await Permission.locationAlways.isGranted;
    final notification = await Permission.notification.isGranted;
    final microphone = await Permission.microphone.isGranted;
    // FLASHLIGHT is a normal (install-time) permission on Android — no runtime
    // dialog exists, so treat it as always available.
    setState(() {
      _locationGranted = locationAlways;
      _notificationGranted = notification;
      _microphoneGranted = microphone;
      _flashlightGranted = true;
    });
  }

  // Requests foreground location first, then escalates to background (always).
  // Both must be granted before _locationGranted becomes true.
  Future<void> _requestLocationPermission() async {
    if (_locationGranted) return;

    // Step 1: foreground location — Android requires this before background.
    final whenInUse = await Permission.locationWhenInUse.request();
    if (!whenInUse.isGranted) {
      if (whenInUse.isPermanentlyDenied) {
        _showSettingsDialog('Location');
      }
      return;
    }

    // Step 2: background location — required for 30-second background updates.
    final always = await Permission.locationAlways.request();
    setState(() {
      _locationGranted = always.isGranted;
    });

    if (always.isPermanentlyDenied) {
      _showSettingsDialog('Background Location');
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

  Future<void> _requestMicrophonePermission() async {
    if (_microphoneGranted) return;

    final status = await Permission.microphone.request();
    setState(() {
      _microphoneGranted = status.isGranted;
    });

    if (status.isPermanentlyDenied) {
      _showSettingsDialog('Microphone');
    }
  }

  // FLASHLIGHT is a normal (install-time) permission on Android — no runtime
  // dialog is possible. Tapping the card marks it confirmed.
  Future<void> _requestFlashlightPermission() async {
    setState(() {
      _flashlightGranted = true;
    });
  }

  // Show dialog to open app settings when a permission is permanently denied.
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

  // Continue is gated on background location and notifications — the two
  // permissions required for core child safety functionality.
  bool get _allPermissionsGranted {
    return _locationGranted && _notificationGranted;
  }

  void _continue() {
    if (_allPermissionsGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChildHomeScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please grant all permissions to ensure your safety'),
          backgroundColor: Color(0xFFFF9800),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
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

              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha:0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security,
                    size: 50,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Safety Permissions',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'These permissions help keep you safe and connected with your parents',
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
                    ChildPermissionCard(
                      icon: Icons.location_on,
                      title: 'Location Access',
                      description: 'Let your parents know where you are',
                      isGranted: _locationGranted,
                      isRequired: true,
                      color: const Color(0xFF4CAF50),
                      onTap: _requestLocationPermission,
                    ),

                    const SizedBox(height: 16),

                    ChildPermissionCard(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      description: 'Receive messages and alerts from parents',
                      isGranted: _notificationGranted,
                      isRequired: true,
                      color: const Color(0xFF4CAF50),
                      onTap: _requestNotificationPermission,
                    ),

                    const SizedBox(height: 16),

                    ChildPermissionCard(
                      icon: Icons.mic,
                      title: 'Microphone Access',
                      description: 'Parents can hear surroundings in emergencies and trigger alert sounds',
                      isGranted: _microphoneGranted,
                      isRequired: true,
                      color: const Color(0xFF4CAF50),
                      onTap: _requestMicrophonePermission,
                    ),

                    const SizedBox(height: 16),

                    ChildPermissionCard(
                      icon: Icons.flashlight_on,
                      title: 'Flashlight Control',
                      description: 'Parents can activate flashlight when phone is on silent or vibrate mode',
                      isGranted: _flashlightGranted,
                      isRequired: true,
                      color: const Color(0xFF4CAF50),
                      onTap: _requestFlashlightPermission,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFF9800),
                    width: 1,
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFFFF9800),
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'All permissions are required for your safety',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFFE65100),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _allPermissionsGranted
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: _allPermissionsGranted ? 3 : 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_allPermissionsGranted) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ],
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

class ChildPermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final bool isRequired;
  final Color color;
  final Future<void> Function() onTap;

  const ChildPermissionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    required this.isRequired,
    required this.color,
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
            color: isGranted ? color : const Color(0xFFBDBDBD),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isGranted
                  ? color.withValues(alpha:0.1)
                  : Colors.black.withValues(alpha:0.05),
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
                    ? color.withValues(alpha:0.1)
                    : const Color(0xFF4CAF50).withValues(alpha:0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: isGranted ? color : const Color(0xFF9E9E9E),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isGranted
                                ? const Color(0xFF212121)
                                : const Color(0xFF757575),
                          ),
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
                            color: const Color(0xFFF44336).withValues(alpha:0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF44336),
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
              color: isGranted ? color : const Color(0xFFBDBDBD),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}