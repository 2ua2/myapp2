import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../auth/child_login_screen.dart';

class ChildVerificationScreen extends StatefulWidget {
  final String familyId;
  final String childName;

  const ChildVerificationScreen({
    super.key,
    required this.familyId,
    required this.childName,
  });

  @override
  State<ChildVerificationScreen> createState() =>
      _ChildVerificationScreenState();
}

class _ChildVerificationScreenState extends State<ChildVerificationScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so button color updates as user types.
    _pinController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    if (widget.familyId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Session error. Please scan QR code again.'),
        backgroundColor: Color(0xFFF44336),
      ));
      return;
    }

    print('ChildVerificationScreen: familyId=${widget.familyId} pin=${_pinController.text.trim()}');

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await AuthService().verifyChildPin(
        familyId: widget.familyId,
        pin: _pinController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChildInfoScreen(
              familyId: widget.familyId,
              childName: widget.childName,
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Invalid PIN. Please try again.'),
            backgroundColor: Color(0xFFF44336),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Invalid PIN. Please try again.'),
          backgroundColor: Color(0xFFF44336),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinReady = _pinController.text.trim().length == 4;

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 50,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Enter Parent PIN Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Enter the PIN code shown in your parent\'s app',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'PIN Code',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: (pinReady && !_isLoading) ? _onContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: pinReady
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
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
