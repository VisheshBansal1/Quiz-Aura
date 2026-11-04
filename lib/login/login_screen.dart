import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_daily_quiz_screen.dart';
import 'package:QuizSphere/core/constants/app_colors.dart';
import 'package:QuizSphere/core/widgets/agreement_text.dart';

import 'auth/auth_service.dart';
import 'create_account_screen.dart';

// ── Named Route constants ────────────────────────────────────────────────────
// Register these in your MaterialApp routes:
//
//   routes: {
//     '/login':   (_) => const LoginScreen(),
//     '/privacy': (_) => const PrivacyPolicyScreen(),
//     '/terms':   (_) => const TermsConditionsScreen(),
//   },

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
  bool isPasswordVisible = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  // ================= EMAIL LOGIN =================
  Future<void> _loginEmail() async {
    if (loading) return;

    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      _error("Email and password required");
      return;
    }

    setState(() => loading = true);
    try {
      final user = await auth.loginWithEmail(email, pass);
      if (!mounted) return;
      _navigateHome(user);
    } catch (e) {
      _error(e.toString().replaceFirst("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ================= GOOGLE LOGIN =================
  Future<void> _loginGoogle() async {
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
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withOpacity(0.12),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Sign in to continue",
                      style: TextStyle(color: Colors.white70),
                    ),

                    const SizedBox(height: 32),

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
                        hintStyle:
                            const TextStyle(color: Colors.white60),
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
                        hintStyle:
                            const TextStyle(color: Colors.white60),
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

                    const SizedBox(height: 28),

                    // ===== Login Button =====
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: loading ? null : _loginEmail,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // ===== Google Login =====
                    // Web only: no Android/iOS OAuth client is configured,
                    // so this — divider included — is skipped entirely on
                    // those platforms rather than just visually hidden.
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
                          onPressed: loading ? null : _loginGoogle,
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

                    // ===== Create Account Link =====
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const CreateAccountScreen(),
                                ),
                              );
                            },
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                          children: [
                            TextSpan(text: "Don't have an account? "),
                            TextSpan(
                              text: "Create one",
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

          // ===== Loading =====
          if (loading)
            Container(
              color: Colors.black.withOpacity(0.4),
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
