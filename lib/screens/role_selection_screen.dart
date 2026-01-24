import 'package:flutter/material.dart';
import 'auth/parent_login_screen.dart';
import 'auth/child_link_account_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              const Text(
                'You are...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2196F3),
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 60),

              RoleButton(
                icon: Icons.family_restroom,
                title: 'Parent',
                description: 'Monitor and protect your children',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ParentLoginScreen(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              RoleButton(
                icon: Icons.child_care,
                title: 'Child',
                description: 'Stay connected with your parents',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChildLinkAccountScreen(),
                    ),
                  );
                },
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}

// RoleButton Widget
class RoleButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const RoleButton({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF2196F3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2196F3).withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2196F3).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
