import 'package:flutter/material.dart';

class ParentProfileScreen extends StatefulWidget {
  const ParentProfileScreen({super.key});

  @override
  State<ParentProfileScreen> createState() => _ParentProfileScreenState();
}

class _ParentProfileScreenState extends State<ParentProfileScreen> {
  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  bool _darkModeEnabled = false;

  @override
  Widget build(BuildContext context) {
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
                        color: const Color(0xFF2196F3).withOpacity(0.3),
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
                  color: Colors.black.withOpacity(0.05),
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
                  value: 'name',
                  onTap: () => print('Edit name'),
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: 'email',
                  onTap: () => print('Edit email'),
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.phone_outlined,
                  title: 'Phone Number',
                  value: 'xxxx-xxxx',
                  onTap: () => print('Edit phone'),
                ),
                _buildDivider(),
                _buildInfoTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location',
                  value: 'Unknown',
                  onTap: () => print('Edit location'),
                ),
              ],
            ),
          ),

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
                  color: Colors.black.withOpacity(0.05),
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
                  color: Colors.black.withOpacity(0.05),
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
                    color: const Color(0xFFF44336).withOpacity(0.3),
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
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF2196F3).withOpacity(0.1),
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
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF212121),
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9E9E9E)),
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
          color: const Color(0xFF2196F3).withOpacity(0.1),
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
      activeColor: const Color(0xFF2196F3),
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
          color: const Color(0xFF2196F3).withOpacity(0.1),
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
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF9E9E9E)),
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
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: const Text('Profile editing feature coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              print('User logged out');
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
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('English'),
              leading: const Icon(Icons.circle_outlined),
              onTap: () {
                Navigator.pop(context);
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}