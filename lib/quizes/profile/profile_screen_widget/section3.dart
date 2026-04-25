import 'package:flutter/material.dart';
import 'package:QuizSphere/login/auth/auth_service.dart';

class Section3 extends StatelessWidget {
  const Section3({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      // AuthService.logout() signs out both Google and Firebase
      await AuthService().logout();
      // AuthWrapper stream will automatically navigate to LoginScreen
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: const Text('About'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {},
        ),
        ListTile(
          leading: const Icon(Icons.logout_outlined),
          title: const Text('Log Out'),
          trailing: const Icon(Icons.arrow_forward_ios_rounded),
          onTap: () => _signOut(context),
        ),
      ],
    );
  }
}
