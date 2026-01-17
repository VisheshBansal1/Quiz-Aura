import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../auth/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final auth = AuthService();

  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginEmail() async {
    if (loading) return;

    if (emailCtrl.text.isEmpty || passCtrl.text.isEmpty) {
      _error("Email and password required");
      return;
    }

    setState(() => loading = true);
    try {
      await auth.loginWithEmail(
        emailCtrl.text.trim(),
        passCtrl.text.trim(),
      );
      // 🔥 NOTHING ELSE
    } catch (e) {
      _error(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loginGoogle() async {
    if (loading) return;

    setState(() => loading = true);
    try {
      await auth.loginWithGoogle();
    } catch (e) {
      _error(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign in")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Welcome",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loginEmail,
                  child: const Text("Login"),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loginGoogle,
                  child: const Text("Login with Google"),
                ),
              ],
            ),
          ),
          if (loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
