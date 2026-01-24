import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'child_authorizations_screen.dart';

class ChildVerificationScreen extends StatefulWidget {
  const ChildVerificationScreen({super.key});

  @override
  State<ChildVerificationScreen> createState() => _ChildVerificationScreenState();
}

class _ChildVerificationScreenState extends State<ChildVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus on code field when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _verifyCode() {
    if (_codeController.text.length == 6) {
      // TODO: Verify code with backend
      print('Code entered: ${_codeController.text}');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ChildAuthorizationsScreen(),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_user,
                  size: 50,
                  color: Color(0xFF4CAF50),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Enter Your Parent\'s Code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),

              const SizedBox(height: 12),

              const Text(
                'Ask your parent for the 6-digit verification code',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF757575),
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 60),

              // Code Input Field
              TextField(
                controller: _codeController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 16,
                  color: Color(0xFF4CAF50),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 16,
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF4CAF50).withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF4CAF50),
                      width: 3,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                ),
                onChanged: (value) {
                  setState(() {});
                  // Auto-verify when 6 digits are entered
                  if (value.length == 6) {
                    _verifyCode();
                  }
                },
              ),

              const SizedBox(height: 16),

              // Code status indicator
              if (_codeController.text.isNotEmpty)
                Center(
                  child: Text(
                    '${_codeController.text.length}/6 digits entered',
                    style: TextStyle(
                      fontSize: 14,
                      color: _codeController.text.length == 6
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFF757575),
                      fontWeight: _codeController.text.length == 6
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),

              const SizedBox(height: 60),

              // Continue Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _codeController.text.length == 6
                      ? _verifyCode
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _codeController.text.length == 6
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFBDBDBD),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      if (_codeController.text.length == 6) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.check_circle, size: 20),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Help text
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2196F3).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF2196F3),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to get the code?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ask your parent to open the app and find the code in their settings',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF2196F3).withOpacity(0.8),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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