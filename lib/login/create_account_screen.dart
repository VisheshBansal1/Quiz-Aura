import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_daily_quiz_screen.dart';
import 'package:QuizSphere/core/constants/app_colors.dart';
import 'package:QuizSphere/core/widgets/glass_card.dart';
import 'package:QuizSphere/core/widgets/agreement_text.dart';

import 'auth/auth_service.dart';

/// Create Account (sign up) screen.
///
/// Google sign-in is web only, matching LoginScreen and
/// AuthService.loginWithGoogle(): no Android/iOS OAuth client is
/// configured, so on Android/iOS this screen only offers email/password
/// registration — the "Continue with Google" button and its divider are
/// skipped entirely on those platforms, not just hidden.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final auth = AuthService();

  bool loading = false;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  // ================= CREATE ACCOUNT (EMAIL) =================
  Future<void> _createAccount() async {
    if (loading) return;

    final name = nameCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final confirmPass = confirmPassCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      _error("Name, email and password are required");
      return;
    }
    if (pass != confirmPass) {
      _error("Passwords do not match");
      return;
    }

    setState(() => loading = true);
    try {
      final user = await auth.registerWithEmail(email, pass, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Account created — verification email sent"),
        ),
      );
      _navigateHome(user);
    } catch (e) {
      _error(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ================= CONTINUE WITH GOOGLE (WEB ONLY) =================
  // Firebase creates the account automatically the first time a Google
  // identity signs in, so this reuses AuthService.loginWithGoogle() —
  // there's no separate "register with Google" call needed.
  Future<void> _continueWithGoogle() async {
    if (loading) return;

    setState(() => loading = true);
    try {
      final user = await auth.loginWithGoogle();
      if (!mounted) return;
      _navigateHome(user);
    } catch (e) {
      _error(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _navigateHome(User user) {
    Widget destination;
    if (user.email == 'admin741@gmail.com') {
      destination = const AdminDailyQuizManagerScreen();
    } else {
      destination = const HomeScreen();
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (_) => false,
    );
  }

  void _error(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ===== Background Gradient =====
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.loginGradient,
            ),
          ),

          // ===== Glass Card =====
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: GlassCard(
                padding: const EdgeInsets.all(24),
                borderRadius: 24,
                backgroundColor: Colors.white.withOpacity(0.12),
                borderColor: Colors.white.withOpacity(0.25),
                elevation: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Sign up to get started",
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 32),

                    // ===== Name =====
                    TextField(
                      controller: nameCtrl,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.person,
                          color: Colors.white70,
                        ),
                        hintText: "Full name",
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== Email =====
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.email,
                          color: Colors.white70,
                        ),
                        hintText: "Email",
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== Password =====
                    TextField(
                      controller: passCtrl,
                      obscureText: !isPasswordVisible,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock,
                          color: Colors.white70,
                        ),
                        hintText: "Password",
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ===== Confirm Password =====
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: !isConfirmPasswordVisible,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Colors.white70,
                        ),
                        hintText: "Confirm password",
                        hintStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isConfirmPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                            color: Colors.white70,
                          ),
                          onPressed: () {
                            setState(() {
                              isConfirmPasswordVisible =
                                  !isConfirmPasswordVisible;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ===== Create Account Button =====
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: loading ? null : _createAccount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // ===== Google Sign-up =====
                    // Web only — see the class doc comment above.
                    if (kIsWeb) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: const [
                          Expanded(child: Divider(color: Colors.white30)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              "OR",
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.white30)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: loading ? null : _continueWithGoogle,
                          icon: const Icon(Icons.g_mobiledata, size: 28),
                          label: const Text(
                            "Continue with Google",
                            style: TextStyle(fontSize: 15),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],

                    // ===== Agreement Text =====
                    const SizedBox(height: 20),
                    const AgreementText(),

                    // ===== Back to Login Link =====
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(text: "Already have an account? "),
                            TextSpan(
                              text: "Log in",
                              style: TextStyle(
                                color: Color(0xFFB3AEFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== Back Button =====
          SafeArea(
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed:
                  loading ? null : () => Navigator.of(context).maybePop(),
            ),
          ),

          // ===== Loading =====
          if (loading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
