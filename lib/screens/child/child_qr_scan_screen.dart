import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/auth_service.dart';
import 'child_verification_screen.dart';

class ChildQrScanScreen extends StatefulWidget {
  final String childName;

  const ChildQrScanScreen({super.key, required this.childName});

  @override
  State<ChildQrScanScreen> createState() => _ChildQrScanScreenState();
}

class _ChildQrScanScreenState extends State<ChildQrScanScreen> {
  bool _isLoading = false;

  Future<void> _startScan() async {
    setState(() => _isLoading = true);

    String? scannedFamilyId;
    bool detected = false;
    final controller = MobileScannerController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.65,
          child: Stack(
            children: [
              MobileScanner(
                controller: controller,
                onDetect: (capture) {
                  if (detected) return;
                  if (capture.barcodes.isEmpty) return;
                  final rawValue = capture.barcodes.first.rawValue;
                  if (rawValue == null || rawValue.isEmpty) return;
                  detected = true;
                  scannedFamilyId = rawValue;
                  controller.stop();
                  Navigator.pop(sheetContext);
                },
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Point camera at parent QR code',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();

    if (scannedFamilyId == null || scannedFamilyId!.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      // Step 1: authenticate before any Firestore writes.
      final uid = await AuthService().signInChildAnonymously();
      print('DIAG-1 uid=$uid');
      if (!mounted) return;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication failed. Try again.'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // Step 2: create the link request now that the user is authenticated.
      final familyId = scannedFamilyId!;
      final requestId = await AuthService().createLinkRequest(
        familyId: familyId,
        childName: widget.childName,
      );
      print('DIAG-2 requestId=$requestId');
      if (!mounted) return;
      if (requestId == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Failed to link. Try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 3: stamp the request with the child's uid so the parent uses
      // it as the document key when writing families/children on approval.
      await FirebaseFirestore.instance
          .collection('link_requests')
          .doc(requestId)
          .update({'childId': uid});
      print('DIAG-3 stamped childId=$uid on requestId=$requestId');
      if (!mounted) return;

      // Step 4: proceed to PIN entry screen.
      print('DIAG-4 navigating to ChildVerificationScreen familyId=$familyId');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChildVerificationScreen(
            familyId: familyId,
            childName: widget.childName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to link. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Parent QR Code'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              const Text(
                'Scan QR Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'Scan your parent\'s QR code to link your account',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _startScan,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
