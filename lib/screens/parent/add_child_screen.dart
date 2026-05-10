import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  String _familyId = '';
  Stream<QuerySnapshot>? _requestsStream;
  // Held so we can remove the listener in dispose without needing context.
  AuthProvider? _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = context.read<AuthProvider>();
    _familyId = _authProvider!.currentUser?.familyId ?? '';
    print('DEBUG familyId: $_familyId');
    print('DEBUG currentUser: ${_authProvider!.currentUser?.uid}');

    if (_familyId.isNotEmpty) {
      _rebuildStream();
    } else {
      // AuthProvider may not have resolved currentUser yet; listen for it.
      _authProvider!.addListener(_onAuthReady);
    }
  }

  void _rebuildStream() {
    print('DEBUG rebuildStream called, familyId: $_familyId');
    // Requires a Firestore composite index on familyId + status.
    _requestsStream = FirebaseFirestore.instance
        .collection('link_requests')
        .where('familyId', isEqualTo: _familyId)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  void _onAuthReady() {
    print('DEBUG onAuthReady fired');
    print('DEBUG new familyId: ${_authProvider?.currentUser?.familyId}');
    final familyId = _authProvider?.currentUser?.familyId ?? '';
    if (familyId.isNotEmpty) {
      _authProvider?.removeListener(_onAuthReady);
      setState(() {
        _familyId = familyId;
        _rebuildStream();
      });
    }
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthReady);
    super.dispose();
  }

  Future<void> _approveRequest(String requestId, String childName, String childId) async {
    // Step 1: re-read request doc to get authoritative field values.
    DocumentSnapshot requestDoc;
    try {
      requestDoc = await FirebaseFirestore.instance
          .collection('link_requests')
          .doc(requestId)
          .get();
    } catch (e) {
      print('approveRequest: failed to read request doc: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to approve. Try again.'),
        backgroundColor: Color(0xFFF44336),
      ));
      return;
    }

    if (!mounted) return;

    if (!requestDoc.exists) {
      print('approveRequest: request doc not found');
      return;
    }
    final data = requestDoc.data()! as Map<String, dynamic>;
    final resolvedChildId = data['childId'] as String? ?? '';
    final resolvedChildName = data['childName'] as String? ?? '';
    final resolvedFamilyId = data['familyId'] as String? ?? '';
    print('approveRequest: childId=$resolvedChildId childName=$resolvedChildName familyId=$resolvedFamilyId');

    // Step 2: validate required fields before writing.
    if (resolvedChildId.isEmpty || resolvedFamilyId.isEmpty) {
      print('approveRequest: missing childId or familyId — aborting');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cannot approve: child has not scanned QR yet.'),
        backgroundColor: Color(0xFFF44336),
      ));
      return;
    }

    // Step 3: write child record to families collection.
    try {
      await FirebaseFirestore.instance
          .collection('families')
          .doc(resolvedFamilyId)
          .collection('children')
          .doc(resolvedChildId)
          .set({
        'childName': resolvedChildName,
        'parentId': resolvedFamilyId,
        'childId': resolvedChildId,
        'linkedAt': FieldValue.serverTimestamp(),
        'status': 'approved',
        'age': '',
        'phone': '',
      });
      print('approveRequest: wrote to families/$resolvedFamilyId/children/$resolvedChildId');
    } catch (e) {
      print('approveRequest: families write FAILED: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to approve. Try again.'),
        backgroundColor: Color(0xFFF44336),
      ));
      return;
    }

    // Step 4: generate 4-digit PIN and update link_request.
    final pin = (Random().nextInt(9000) + 1000).toString();
    try {
      await FirebaseFirestore.instance
          .collection('link_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'pin': pin,
        'approvedAt': FieldValue.serverTimestamp(),
      });
      print('approveRequest: updated link_request status=approved pin=$pin');
    } catch (e) {
      print('approveRequest: link_request update FAILED: $e');
    }

    // Step 5: show PIN in a dialog the parent must manually dismiss so they
    // have time to read it aloud to the child before it disappears.
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Child Approved'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this PIN with your child:'),
            const SizedBox(height: 16),
            Text(
              pin,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Child must enter this PIN in their app',
              style: TextStyle(fontSize: 13, color: Color(0xFF757575)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _denyRequest(String requestId) async {
    try {
      await FirebaseFirestore.instance
          .collection('link_requests')
          .doc(requestId)
          .update({'status': 'denied'});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to deny request')),
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
        title: const Text(
          'Add Child',
          style: TextStyle(
            color: Color(0xFF2196F3),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                children: [
                  const Text(
                    'Scan this QR code',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ask your child to scan this code in the app',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: 240,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFF2196F3),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: _familyId.isEmpty ? 'not-available' : _familyId,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _familyId.isEmpty ? 'Not available' : _familyId,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: const Text(
                  'Pending Requests',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF212121),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _requestsStream == null
                  ? const Center(
                      child: Text(
                        'Sign in to see requests',
                        style: TextStyle(color: Color(0xFF757575)),
                      ),
                    )
                  : StreamBuilder<QuerySnapshot>(
                      stream: _requestsStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          print('DEBUG stream error: ${snapshot.error}');
                          return const Center(
                            child: Text(
                              'Failed to load requests',
                              style: TextStyle(color: Color(0xFF757575)),
                            ),
                          );
                        }
                        print('DEBUG snapshot docs count: ${snapshot.data?.docs.length}');
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No pending requests',
                              style: TextStyle(color: Color(0xFF757575)),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            final requestId = docs[index].id;
                            final childName =
                                data['childName'] as String? ?? 'Unknown';
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      childName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Wants to join your family',
                                      style: TextStyle(
                                        color: Color(0xFF757575),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _approveRequest(
                                                requestId,
                                                childName,
                                                data['childId'] as String? ?? ''),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF4CAF50),
                                              foregroundColor: Colors.white,
                                            ),
                                            child: const Text('Approve'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () =>
                                                _denyRequest(requestId),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(
                                                  color: Colors.red),
                                            ),
                                            child: const Text('Deny'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
