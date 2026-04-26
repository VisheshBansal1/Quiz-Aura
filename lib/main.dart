// ============================================================
// FILE: lib/main.dart
// FIXES:
//   1. Firebase.initializeApp wrapped in try/catch
//   2. Auth stream error handled gracefully
// ============================================================

import 'package:QuizSphere/ads/services/admob_service.dart';
import 'package:QuizSphere/login/login_screen.dart';
import 'package:QuizSphere/quizes/admin/screens/admin_daily_quiz_screen.dart';
import 'package:QuizSphere/quizes/home/onboarding_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'firebase_options.dart';
import 'core/services/fcm_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── .env ──────────────────────────────────────────────────
  // FIX 4: Log dotenv failures instead of swallowing them silently.
  // If .env is missing from pubspec.yaml assets, this throws and the app
  // continues with an empty env — which means API keys won't be found.
  // REQUIRED in pubspec.yaml:
  //   flutter:
  //     assets:
  //       - .env
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[dotenv] Failed to load .env file: $e');
    debugPrint(
      '[dotenv] Make sure .env is listed under flutter > assets in pubspec.yaml',
    );
  }

  // ── Firebase ───────────────────────────────────────────────
  // FIX: Wrap in try/catch — a bad google-services.json or wrong SHA
  // fingerprint was throwing here and crashing before any widget rendered.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[Firebase] initializeApp failed: $e');
  }

  // ── AdMob ─────────────────────────────────────────────────
  if (!kIsWeb) {
    try {
      await AdmobService.initialize();
    } catch (e) {
      debugPrint('[AdMob] init skipped: $e');
    }
  }

  // ── FCM ───────────────────────────────────────────────────
  if (!kIsWeb) {
    try {
      await FcmService.init();
    } catch (e) {
      debugPrint('[FCM] init skipped: $e');
    }
  }

  runApp(const ProviderScope(child: QuizApp()));
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
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        // FIX: Handle auth stream errors gracefully instead of crashing.
        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: Color(0xFF151022),
            body: Center(
              child: Text(
                'Authentication error.\nPlease restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        final user = snapshot.data!;

        if (user.email == 'admin741@gmail.com') {
          return const AdminDailyQuizManagerScreen();
        }

        if (!kIsWeb) {
          FcmService.saveTokenForUser(user.uid);
        }

        return const HomeScreen();
      },
    );
  }
}
