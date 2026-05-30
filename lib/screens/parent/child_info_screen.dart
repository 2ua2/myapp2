import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';
import 'add_child_screen.dart';
import 'message_screen.dart';
import 'location_history_screen.dart';
import 'geofence_screen.dart';

class ChildInfoScreen extends StatefulWidget {
  final String childName;
  final String childId;

  const ChildInfoScreen({
    super.key,
    required this.childName,
    required this.childId,
  });

  @override
  State<ChildInfoScreen> createState() => _ChildInfoScreenState();
}

class _ChildInfoScreenState extends State<ChildInfoScreen> {
  bool _isLoading = true;
  String _childName = 'Child';
  String _familyId = '';
  String _age = 'N/A';
  String _phoneNumber = 'N/A';
  String _currentLocation = 'Location unavailable';

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _childDocSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _childFallbackSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _locationSubscription;

  // True when a real childId was passed by the caller; false means no child linked.
  bool get _hasChild => widget.childId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    print('ChildInfoScreen initState: childId="${widget.childId}" childName="${widget.childName}"');
    _checkLinkedChild();
  }

  @override
  void dispose() {
    _childDocSubscription?.cancel();
    _childFallbackSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkLinkedChild() async {
    print('_checkLinkedChild: childId="${widget.childId}" familyId="$_familyId"');
    final auth = context.read<AuthProvider>();
    final familyId = auth.currentUser?.familyId;

    if (familyId == null || familyId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _familyId = familyId;

    if (widget.childId.isNotEmpty) {
      // Case 1: specific child — subscribe to the document for live updates.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      print('_checkLinkedChild path: families/$uid/children/${widget.childId}');
      _childDocSubscription = FirebaseFirestore.instance
          .collection('families')
          .doc(uid)
          .collection('children')
          .doc(widget.childId)
          .snapshots()
          .listen(
        (doc) {
          if (!mounted) return;
          final data = doc.data();
          if (data == null) return;
          print('child doc update: status=${data['status']} age=${data['age']} phone=${data['phone']}');
          final status = data['status'] as String? ?? '';
          setState(() {
            _childName = widget.childName;
            _isLoading = false;
            if (status == 'linked') {
              _age = data['age']?.toString() ?? 'N/A';
              _phoneNumber = data['phone']?.toString()
                  ?? data['phoneNumber']?.toString()
                  ?? 'N/A';
            } else {
              _age = 'Pending...';
              _phoneNumber = 'Pending...';
            }
          });
        },
        onError: (e) {
          print('_checkLinkedChild doc stream error: $e');
          if (mounted) setState(() => _isLoading = false);
        },
      );

      _locationSubscription = FirebaseFirestore.instance
          .collection('locations')
          .doc(widget.childId)
          .collection('history')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots()
          .listen(
        (snapshot) {
          if (!mounted) return;
          if (snapshot.docs.isEmpty) return;
          final locData = snapshot.docs.first.data();
          final lat = locData['latitude'];
          final lng = locData['longitude'];
          if (lat != null && lng != null) {
            setState(() => _currentLocation = '$lat, $lng');
          }
        },
        onError: (e) {
          print('location stream error: $e');
        },
      );
      return;
    }

    // Case 2: fallback — subscribe to first linked child (status filter applied).
    _childFallbackSubscription = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('children')
        .where('status', isEqualTo: 'linked')
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (!mounted) return;
        if (snapshot.docs.isEmpty) {
          setState(() => _isLoading = false);
          return;
        }
        final data = snapshot.docs.first.data();
        setState(() {
          _childName = data['childName'] as String? ?? 'Child';
          _age = data['age']?.toString() ?? 'N/A';
          _phoneNumber = data['phone']?.toString()
              ?? data['phoneNumber']?.toString()
              ?? 'N/A';
          _isLoading = false;
        });
      },
      onError: (e) {
        print('_checkLinkedChild fallback stream error: $e');
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  void _showQRCode() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your Family Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            QrImageView(
              data: _familyId.isEmpty ? 'not-available' : _familyId,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
            ),
            SelectableText(
              _familyId.isEmpty ? 'Not available' : _familyId,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF757575)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Share this code with your child',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _onCallPressed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.phone, color: Colors.white),
            const SizedBox(width: 12),
            Text('Calling $_childName...'),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _onMessagePressed() {
    final parentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    debugPrint('[CHAT-DIAG-CHILDINFO] parentUid=$parentUid widgetChildId=${widget.childId} chatId=${parentUid}_${widget.childId}');
    if (parentUid.isEmpty || widget.childId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MessageScreen(
          childName: _childName,
          chatId: '${parentUid}_${widget.childId}',
          senderId: parentUid,
          recipientId: widget.childId,
          senderRole: 'parent',
        ),
      ),
    );
  }

  void _onGeofencePressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GeofenceScreen(
          childName: _childName,
        ),
      ),
    );
  }

  void _onLocationHistoryPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationHistoryScreen(
          childName: _childName,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2196F3)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Child Profile',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF2196F3)),
            onPressed: _onAddChild,
          ),
        ],
      ),
      body: SafeArea(
        child: _hasChild
            ? (_isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLinkedContent())
            : _buildEmptyState(),
      ),
    );
  }

  void _onAddChild() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddChildScreen(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.family_restroom,
            size: 80,
            color: Color(0xFFBDBDBD),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add Your Family',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Link your child to start monitoring',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF757575),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: 200,
            height: 56,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text(
                'Show QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: _onAddChild,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Child Profile Card - Horizontal Layout
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.child_care,
                          size: 40,
                          color: Color(0xFF2196F3),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Name and Status
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.childName,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.greenAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active • $_childName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Information Section Title
                const Text(
                  'Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),

                const SizedBox(height: 16),

                // All Info in One Box
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        icon: Icons.cake,
                        label: 'Age',
                        value: _age,
                        color: const Color(0xFFFF9800),
                      ),
                      const Divider(height: 32, thickness: 1),
                      _buildInfoRow(
                        icon: Icons.phone,
                        label: 'Phone Number',
                        value: _phoneNumber,
                        color: const Color(0xFF4CAF50),
                      ),
                      const Divider(height: 32, thickness: 1),
                      _buildInfoRow(
                        icon: Icons.location_on,
                        label: 'Current Location',
                        value: _currentLocation,
                        color: const Color(0xFFF44336),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Geofence Button (Safe Zone)
                GestureDetector(
                  onTap: _onGeofencePressed,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
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
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF2196F3).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_city,
                            color: Color(0xFF2196F3),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Safe Zones',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2196F3),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Set up geofence areas',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF2196F3),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Location History Button
                GestureDetector(
                  onTap: _onLocationHistoryPressed,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9C27B0).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF9C27B0),
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF9C27B0).withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history,
                            color: Color(0xFF9C27B0),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location History',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9C27B0),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'View past locations',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          color: Color(0xFF9C27B0),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Bottom Navigation Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBottomNavItem(
                    icon: Icons.phone,
                    label: 'Call',
                    onTap: _onCallPressed,
                  ),
                  _buildBottomNavItem(
                    icon: Icons.message,
                    label: 'Message',
                    onTap: _onMessagePressed,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF757575),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFF2196F3),
                size: 28,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
