import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/notification_service.dart';
import '../../services/location_service.dart';
import '../parent/message_screen.dart';

class ChildHomeScreen extends StatefulWidget {
  final String familyId;

  const ChildHomeScreen({super.key, required this.familyId});

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  String _parentName = 'Parent';
  String _parentPhone = '';
  final String _parentRelation = 'Parent';
  bool _isConnected = false;
  // ignore: unused_field
  bool _sosSending = false;
  // ignore: unused_field
  bool _alarmSending = false;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    print('[CHILD-INIT] uid=${FirebaseAuth.instance.currentUser?.uid}');
    _startLocationWriter();
    _fetchParentInfo();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  // Reads the parent's name and phone from users/{familyId} and updates state.
  // familyId == parentUid by convention (set during parent sign-up).
  Future<void> _fetchParentInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('[CHILD-PARENT-INFO] currentUser is null, skipping fetch');
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.familyId)
          .get();
      if (!mounted) return;
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _parentName = data['name'] as String? ?? 'Parent';
          // Parents do not have a phone field written during sign-up;
          // fall back to empty so the caller can show 'Not available'.
          _parentPhone = data['phoneNumber'] as String? ?? '';
          _isConnected = true;
        });
        print('[CHILD-PARENT-INFO] name=$_parentName phone=$_parentPhone');
      } else {
        setState(() => _isConnected = false);
        print('[CHILD-PARENT-INFO] parent doc not found for familyId=${widget.familyId}');
      }
    } catch (e) {
      print('[CHILD-PARENT-INFO] error: $e');
      if (!mounted) return;
    }
  }

  // Starts a GPS position stream that writes each fix to /locations/{childId}/history.
  // Uses the child's Firebase Auth uid so the parent can read from the correct path.
  void _startLocationWriter() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final childId = user.uid;
    final familyId = widget.familyId;
    final locationService = LocationService();

    _locationSub?.cancel();
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (position) async {
        try {
          print('[CHILD-WRITE] path=locations/$childId/history lat=${position.latitude} lng=${position.longitude}');
          await locationService.writeChildLocation(
            childId,
            familyId,
            position.latitude,
            position.longitude,
          );
          print('[CHILD-WRITE-OK] docId=n/a');
        } catch (e) {
          print('[CHILD-WRITE-ERR] $e');
          print('_startLocationWriter write error: $e');
        }
      },
      onError: (e) => print('_startLocationWriter stream error: $e'),
    );
  }

  void _onSOSPressed() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withValues(alpha:0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: Color(0xFFF44336),
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'SOS Alert',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to send an emergency alert to your parents?',
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF757575),
                fontSize: 16,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendSOSAlert();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Send SOS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSOSAlert() async {
    setState(() => _sosSending = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not logged in.'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      setState(() => _sosSending = false);
      return;
    }
    final uid = user.uid;

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      print('SOS location error: $e');
    }
    if (!mounted) return;

    String childName = 'Child';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      childName = doc.data()?['name'] as String? ?? 'Child';
    } catch (e) {
      print('SOS get name error: $e');
    }
    if (!mounted) return;

    print('[CHILD-SOS-PRESS] childUid=$uid familyId=${widget.familyId}');
    final success = await NotificationService().sendSosAlert(
      childId: uid,
      familyId: widget.familyId,
      lat: position?.latitude ?? 0.0,
      lng: position?.longitude ?? 0.0,
      childName: childName,
    );
    print('[CHILD-SOS-RESULT] ok=$success');
    if (!mounted) return;
    setState(() => _sosSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'SOS sent to your parent!'
              : 'Failed to send SOS. Try again.',
        ),
        backgroundColor: success
            ? const Color(0xFF4CAF50)
            : const Color(0xFFF44336),
      ),
    );
  }

  void _onCallPressed() {
    print('Call parent');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Calling $_parentName...'),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onAlarmPressed() async {
    setState(() => _alarmSending = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not logged in.'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
      setState(() => _alarmSending = false);
      return;
    }
    final uid = user.uid;

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      print('Alarm location error: $e');
    }
    if (!mounted) return;

    String childName = 'Child';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      childName = doc.data()?['name'] as String? ?? 'Child';
    } catch (e) {
      print('Alarm get name error: $e');
    }
    if (!mounted) return;

    print('[CHILD-ALARM-PRESS] childUid=$uid familyId=${widget.familyId}');
    final success = await NotificationService().sendAlarmAlert(
      childId: uid,
      familyId: widget.familyId,
      lat: position?.latitude ?? 0.0,
      lng: position?.longitude ?? 0.0,
      childName: childName,
    );
    print('[CHILD-ALARM-RESULT] ok=$success');
    if (!mounted) return;
    setState(() => _alarmSending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Alarm sent to your parent!'
              : 'Failed to send alarm. Try again.',
        ),
        backgroundColor: success
            ? const Color(0xFF4CAF50)
            : const Color(0xFFF44336),
      ),
    );
  }

  void _onMessagePressed() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in.')),
      );
      return;
    }
    final childId = user.uid;
    final chatId = '${widget.familyId}_$childId';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          chatId: chatId,
          senderId: childId,
          recipientId: widget.familyId,
          childName: _parentName,
          senderRole: 'child',
        ),
      ),
    );
  }

  void _onFamilyPressed() {
    print('Open family contacts');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FamilyContactsScreen(
          name: _parentName,
          phone: _parentPhone.isEmpty ? 'Not available' : _parentPhone,
          relation: _parentRelation,
          isActive: _isConnected,
        ),
      ),
    );
  }

  void _onSettingsPressed() {
    print('Open settings');
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF4CAF50)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 90,
        decoration: BoxDecoration(
          color: color.withValues(alpha:0.1),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Safe Child',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF2196F3)),
            onPressed: _onSettingsPressed,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Parent Info Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GestureDetector(
                  onTap: () {
                    print('View parent info');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4CAF50),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _parentName,
                                style: const TextStyle(
                                  fontSize: 18,
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
                                      color: _isConnected
                                          ? Colors.greenAccent
                                          : Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isConnected ? 'Connected' : 'Offline',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF4CAF50),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 18, color: Color(0xFF2196F3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Location Sharing: Active',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Safety Status Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.shield, 'Safety Status', 'Active'),
                      const Divider(height: 24),
                      _buildInfoRow(Icons.wifi, 'Connection', 'Online'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // SOS Button
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF44336),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF44336).withValues(alpha:0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _onSOSPressed,
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

                    // Call + Alarm
                    Row(
                      children: [
                        Expanded(
                          child: _buildSquareControl(
                            icon: Icons.call,
                            label: 'Call',
                            color: const Color(0xFF2196F3),
                            onTap: _onCallPressed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSquareControl(
                            icon: Icons.notifications_active,
                            label: 'Alarm',
                            color: const Color(0xFF2196F3),
                            onTap: _onAlarmPressed,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Message + Family
                    Row(
                      children: [
                        Expanded(
                          child: _buildSquareControl(
                            icon: Icons.message,
                            label: 'Message',
                            color: const Color(0xFF2196F3),
                            onTap: _onMessagePressed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSquareControl(
                            icon: Icons.family_restroom,
                            label: 'Family',
                            color: const Color(0xFF2196F3),
                            onTap: _onFamilyPressed,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FamilyContactsScreen extends StatelessWidget {
  final String name;
  final String phone;
  final String relation;
  final bool isActive;

  const FamilyContactsScreen({
    super.key,
    required this.name,
    required this.phone,
    required this.relation,
    required this.isActive,
  });

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
        title: const Text(
          'Family Contacts',
          style: TextStyle(
            color: Color(0xFF4CAF50),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _FamilyContactCard(
                name: name,
                phone: phone,
                relation: relation,
                isActive: isActive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FamilyContactCard extends StatelessWidget {
  final String name;
  final String phone;
  final String relation;
  final bool isActive;

  const _FamilyContactCard({
    required this.name,
    required this.phone,
    required this.relation,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha:0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF4CAF50), width: 2),
            ),
            child: const Icon(
              Icons.person,
              size: 28,
              color: Color(0xFF4CAF50),
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
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isActive)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  relation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  phone,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.phone,
              color: Color(0xFF4CAF50),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Calling $name...'),
                  backgroundColor: const Color(0xFF4CAF50),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}