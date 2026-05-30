import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../role_selection_screen.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  bool _darkModeEnabled = false;
  String _locationText = 'Fetching...';
  String? _phoneNumber;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _loadPhoneNumber();
  }

  Future<void> _fetchLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationText = 'Permission denied');
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (!mounted) return;
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() => _locationText = '${p.locality}, ${p.country}');
        } else {
          setState(() =>
              _locationText = '${position.latitude}, ${position.longitude}');
        }
      } catch (_) {
        if (!mounted) return;
        setState(() =>
            _locationText = '${position.latitude}, ${position.longitude}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationText = 'Location unavailable');
    }
  }

  // Reads phone from Firestore as the source of truth, syncs to SharedPreferences,
  // and falls back to SharedPreferences if the Firestore doc is missing the field
  // or if the read fails (e.g. offline).
  Future<void> _loadPhoneNumber() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;

      final firestorePhone = doc.data()?['phoneNumber'] as String?;

      if (firestorePhone != null && firestorePhone.isNotEmpty) {
        // Firestore has a value — treat it as source of truth and update local cache.
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        await prefs.setString('phone_number', firestorePhone);
        if (!mounted) return;
        setState(() => _phoneNumber = firestorePhone);
        print('[PROFILE] phone loaded from Firestore uid=$uid');
      } else {
        // No phone in Firestore yet — fall back to local SharedPreferences cache.
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        setState(() => _phoneNumber = prefs.getString('phone_number'));
        print('[PROFILE] phone not in Firestore, using SharedPreferences: $_phoneNumber');
      }
    } catch (e) {
      print('[PROFILE] error loading phone: $e');
      if (!mounted) return;
      // Best-effort fallback to SharedPreferences when Firestore is unavailable.
      try {
        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        setState(() => _phoneNumber = prefs.getString('phone_number'));
      } catch (_) {}
    }
  }

  Future<void> _showEditDialog(String fieldName, String currentValue) async {
    await showDialog<void>(
      context: context,
      // controller is created inside the builder so its lifetime is bound to
      // the dialog widget — this avoids disposing it while the TextField is
      // still attached during the dismiss animation
      builder: (dialogContext) {
        final controller = TextEditingController(text: currentValue);
        return AlertDialog(
          title: Text('Edit $fieldName'),
          content: TextField(
            controller: controller,
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newValue = controller.text.trim();
                Navigator.pop(dialogContext);
                _saveField(fieldName, newValue);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveField(String fieldName, String value) async {
    // cache provider reference before any await to avoid context use in async gap
    final auth = context.read<AuthProvider>();
    final currentUser = auth.currentUser;
    if (currentUser == null) return;

    setState(() => _isSaving = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      switch (fieldName) {
        case 'Name':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'name': value});
          if (!mounted) return;
          await auth.refreshUser();
          break;
        case 'Email':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'email': value});
          if (!mounted) return;
          await auth.refreshUser();
          break;
        case 'Phone Number':
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .update({'phoneNumber': value});
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('phone_number', value);
          if (!mounted) return;
          setState(() => _phoneNumber = value);
          break;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Update failed'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    final String nameValue =
        (currentUser?.name.isNotEmpty ?? false) ? currentUser!.name : 'Not set';
    final bool nameWarning = currentUser == null || currentUser.name.isEmpty;

    final String emailValue =
        (currentUser?.email.isNotEmpty ?? false) ? currentUser!.email : 'Not set';
    final bool emailWarning = currentUser == null || currentUser.email.isEmpty;

    // TODO: add phoneNumber to UserModel in Phase 9
    final String phoneValue =
        (_phoneNumber != null && _phoneNumber!.isNotEmpty) ? _phoneNumber! : 'Not set';
    final bool phoneWarning = _phoneNumber == null || _phoneNumber!.isEmpty;

    final bool locationWarning = _locationText == 'Permission denied' ||
        _locationText == 'Location unavailable';

    final bool hasAnyWarning = phoneWarning || locationWarning;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF212121)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF212121),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF2196F3)),
            onPressed: () => _showEditProfileDialog(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Header
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2196F3),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Account Information
          _buildSectionTitle('Account Information'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.person_outline,
                  title: 'Name',
                  value: nameValue,
                  isWarning: nameWarning,
                  onTap: _isSaving
                      ? () {}
                      : () => _showEditDialog('Name', currentUser?.name ?? ''),
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: emailValue,
                  isWarning: emailWarning,
                  onTap: _isSaving
                      ? () {}
                      : () =>
                          _showEditDialog('Email', currentUser?.email ?? ''),
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone Number',
                  value: phoneValue,
                  isWarning: phoneWarning,
                  onTap: _isSaving
                      ? () {}
                      : () => _showEditDialog(
                          'Phone Number', _phoneNumber ?? ''),
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: _locationText,
                  isWarning: locationWarning,
                  onTap: () => print('Edit Location'),
                ),
              ],
            ),
          ),

          if (hasAnyWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFF9800)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Some profile information is incomplete. Tap a field to update.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Settings
          _buildSectionTitle('Settings'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSwitchTile(
                  icon: Icons.notifications_outlined,
                  title: 'Push Notifications',
                  value: _notificationsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _notificationsEnabled = value;
                    });
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location Sharing',
                  value: _locationSharingEnabled,
                  onChanged: (value) {
                    setState(() {
                      _locationSharingEnabled = value;
                    });
                  },
                ),
                _buildDivider(),
                _buildSwitchTile(
                  icon: Icons.dark_mode_outlined,
                  title: 'Dark Mode',
                  value: _darkModeEnabled,
                  onChanged: (value) {
                    setState(() {
                      _darkModeEnabled = value;
                    });
                  },
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.language,
                  title: 'Language',
                  trailing: Text(
                    'English',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  onTap: () => _showLanguageDialog(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Other Options
          _buildSectionTitle('Other'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildMenuTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  onTap: () => print('Change password'),
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () => print('Privacy policy'),
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.help_outline,
                  title: 'Help & Support',
                  onTap: () => print('Help'),
                ),
                _buildDivider(),
                _buildMenuTile(
                  icon: Icons.info_outline,
                  title: 'About',
                  onTap: () => print('About'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logout Button
          Center(
            child: Container(
              width: 200,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF44336).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => _showLogoutDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF44336),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Color(0xFF757575),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
    bool isWarning = false,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2196F3)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF757575),
        ),
      ),
      subtitle: isWarning
          ? Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFFFF9800),
                ),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFF9800),
                  ),
                ),
              ],
            )
          : Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
            ),
      trailing: const Icon(
          Icons.arrow_forward_ios, size: 16, color: Color(0xFF9E9E9E)),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      secondary: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2196F3)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212121),
        ),
      ),
      value: value,
      activeThumbColor: const Color(0xFF2196F3),
      onChanged: onChanged,
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: const Color(0xFF2196F3)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212121),
        ),
      ),
      trailing: trailing ??
          const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9E9E9E)),
      onTap: onTap,
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 80,
      endIndent: 16,
      color: Color(0xFFE0E0E0),
    );
  }

  void _showEditProfileDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Profile'),
        content: const Text('Profile editing feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    // use 'dialogContext' so the outer state 'context' remains accessible
    // inside the async onPressed without being shadowed by the builder param
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // cache provider reference before pop so the dialog context is
              // not used after it has been removed from the tree
              final auth = context.read<AuthProvider>();
              Navigator.pop(dialogContext);
              try {
                await auth.signOut();
                if (!mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                      builder: (_) => const RoleSelectionScreen()),
                  (route) => false,
                );
              } catch (e) {
                print('[PROFILE] logout error: $e');
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFF44336),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: const Icon(Icons.circle_outlined),
              onTap: () {
                Navigator.pop(dialogContext);
                print('Language: English');
              },
            ),
            ListTile(
              title: const Text('Arabic'),
              leading: const Icon(Icons.circle_outlined),
              enabled: false,
              onTap: () {},
            ),
            ListTile(
              title: const Text('Spanish'),
              leading: const Icon(Icons.circle_outlined),
              enabled: false,
              onTap: () {},
            ),
            ListTile(
              title: const Text('French'),
              leading: const Icon(Icons.circle_outlined),
              enabled: false,
              onTap: () {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
