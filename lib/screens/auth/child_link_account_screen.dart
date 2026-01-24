import 'package:flutter/material.dart';
import 'child_login_screen.dart';
import '../child/child_verification_screen.dart';

class ChildLinkAccountScreen extends StatefulWidget {
  const ChildLinkAccountScreen({super.key});

  @override
  State<ChildLinkAccountScreen> createState() => _ChildLinkAccountScreenState();
}

class _ChildLinkAccountScreenState extends State<ChildLinkAccountScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  bool _showCodeField = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendRequest() {
    // Navigate directly without validation (no backend)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChildVerificationScreen(),
      ),
    );
  }


  void _scanQRCode() {
    print('Scan QR Code pressed');
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
        child: SingleChildScrollView(
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
                  Icons.link,
                  size: 50,
                  color: Color(0xFF2196F3),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Find your parent',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Enter parent email or scan QR code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                ),
              ),

              const SizedBox(height: 40),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Parent Email',
                  hintText: 'Enter parent email address',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _sendRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2196F3),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Send',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              if (_showCodeField) ...[
                const SizedBox(height: 24),

                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: 'Enter Code',
                    hintText: 'Enter 6-digit code',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_codeController.text.length == 6) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ChildVerificationScreen(),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid 6-digit code'),
                            backgroundColor: Color(0xFFF44336),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
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
              ],

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFFBDBDBD),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: const Color(0xFFBDBDBD),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _scanQRCode,
                  icon: const Icon(Icons.qr_code_scanner, size: 28),
                  label: const Text(
                    'Scan QR Code',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2196F3), width: 2),
                    foregroundColor: const Color(0xFF2196F3),
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