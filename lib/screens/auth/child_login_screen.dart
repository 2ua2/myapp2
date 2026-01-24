import 'package:flutter/material.dart';
import '../child/child_authorizations_screen.dart';

class ChildLoginScreen extends StatefulWidget {
const ChildLoginScreen({super.key});

@override
State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
final TextEditingController _emailController = TextEditingController();
final TextEditingController _passwordController = TextEditingController();
bool _obscurePassword = true;

@override
void dispose() {
_emailController.dispose();
_passwordController.dispose();
super.dispose();
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
const SizedBox(height: 20),

Container(
width: 100,
height: 100,
decoration: BoxDecoration(
color: const Color(0xFF4CAF50).withOpacity(0.1),
shape: BoxShape.circle,
),
child: const Icon(
Icons.child_care,
size: 50,
color: Color(0xFF4CAF50),
),
),

const SizedBox(height: 32),

const Text(
'Welcome',
textAlign: TextAlign.center,
style: TextStyle(
fontSize: 28,
fontWeight: FontWeight.bold,
color: Color(0xFF212121),
),
),

const SizedBox(height: 8),

const Text(
'Login to your account',
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
labelText: 'Email',
hintText: 'Enter your email',
prefixIcon: const Icon(Icons.email_outlined),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
),
),

const SizedBox(height: 16),

TextField(
controller: _passwordController,
obscureText: _obscurePassword,
decoration: InputDecoration(
labelText: 'Password',
hintText: 'Enter your password',
prefixIcon: const Icon(Icons.lock_outlined),
suffixIcon: IconButton(
icon: Icon(
_obscurePassword ? Icons.visibility_off : Icons.visibility,
),
onPressed: () {
setState(() {
_obscurePassword = !_obscurePassword;
});
},
),
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(12),
),
),
),

const SizedBox(height: 12),

Align(
alignment: Alignment.centerRight,
child: TextButton(
onPressed: () {
print('Forgot password pressed');
},
child: const Text(
'Forgot password?',
style: TextStyle(
color: Color(0xFF757575),
fontSize: 14,
fontWeight: FontWeight.w300,
),
),
),
),

const SizedBox(height: 24),

  SizedBox(
    height: 56,
    child: ElevatedButton(
      onPressed: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ChildAuthorizationsScreen(),
          ),
        );
      },
style: ElevatedButton.styleFrom(
backgroundColor: const Color(0xFF4CAF50),
foregroundColor: Colors.white,
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(12),
),
),
child: const Text(
'Login',
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
