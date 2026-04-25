// ============================================================
// FILE: lib/main.dart
// WEB FIX: dotenv wrapped in try/catch, FCM skipped on web,
//          GoogleSignIn gets clientId on web only.
// ============================================================

import 'package:QuizSphere/login/login_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_daily_quiz_screen.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'core/services/fcm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── .env ──────────────────────────────────────────────────
  // On web the .env file is often missing from the build output
  // and dotenv.load() throws, freezing the app before Firebase
  // even starts. Wrap in try/catch so startup always continues.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env not found on web — API keys must come from firebase_options.dart
    // or be baked in. Safe to continue.
  }

  // ── Firebase ───────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── FCM ────────────────────────────────────────────────────
  // FCM uses native push APIs that are NOT available on web.
  // Calling FcmService.init() on web throws and freezes the app.
  if (!kIsWeb) {
    try {
      await FcmService.init();
    } catch (e) {
      debugPrint('[FCM] init skipped: $e');
    }
  }

  runApp(
    const ProviderScope(
      child: QuizApp(),
    ),
  );
}

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'QuizAura',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        appBarTheme: const AppBarTheme(
          color: Colors.teal,
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF151022),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        // ADMIN CHECK
        if (user.email == 'admin741@gmail.com') {
          return const AdminDailyQuizManagerScreen();
        }

        // Save FCM token only on non-web platforms
        if (!kIsWeb) {
          FcmService.saveTokenForUser(user.uid);
        }

        return const HomeScreen();
      },
    );
  }
}
