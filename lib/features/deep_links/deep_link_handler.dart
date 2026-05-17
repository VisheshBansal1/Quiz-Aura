// ============================================================
// FILE: lib/features/deep_links/deep_link_handler.dart
//
// Handles ALL incoming deep links for QuizAura:
//   Quiz:       https://quizaura.netlify.app/quiz/{quizId}
//   Tournament: https://quizaura.netlify.app/tournament/{tournamentId}
//   Battle:     https://quizaura.netlify.app/battle/{battleId}  (existing)
//
// HOW TO WIRE (see bottom of file for copy-paste snippets):
//   1. Add `app_links` package to pubspec.yaml
//   2. Configure AndroidManifest.xml  (snippet below)
//   3. Configure ios/Runner/Info.plist (snippet below)
//   4. Call DeepLinkHandler.init() in main.dart
//   5. Pass DeepLinkHandler.navigatorKey to MaterialApp
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:app_links/app_links.dart';

// Navigation targets
import 'package:QuizSphere/quizes/home/quiz_rules_screen.dart';
import 'package:QuizSphere/quizes/home/quiz_attempt_screen.dart';
import 'package:QuizSphere/quizes/home/quiz_ended_screen.dart';
import 'package:QuizSphere/features/tournament/screens/tournament_detail_screen.dart';
import 'package:QuizSphere/features/tournament/services/tournament_service.dart';
import 'package:QuizSphere/features/battle/screens/battle_home_screen.dart';
import 'package:QuizSphere/features/battle/screens/battle_active_screen.dart';
import 'package:QuizSphere/features/battle/services/battle_v2_service.dart';

class DeepLinkHandler {
  DeepLinkHandler._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static late AppLinks _appLinks;

  // Pending links received before login / before navigator is ready
  static Uri? _pendingLink;

  // ── Call once from main() after Firebase.initializeApp() ─────────────────
  static Future<void> init() async {
    _appLinks = AppLinks();

    // Cold-start link (app was NOT running when link was tapped)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('[DeepLink] Cold-start: $initialUri');
        _pendingLink = initialUri;
      }
    } catch (e) {
      debugPrint('[DeepLink] getInitialLink error: $e');
    }

    // Foreground links (app IS running when link is tapped)
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('[DeepLink] Foreground: $uri');
      _handleUri(uri);
    }, onError: (e) => debugPrint('[DeepLink] stream error: $e'));
  }

  // ── Call this after user logs in (processes any cold-start pending link) ─
  static Future<void> processPendingLink() async {
    final uri = _pendingLink;
    if (uri == null) return;
    _pendingLink = null;

    // Small delay so the navigator is fully mounted
    await Future.delayed(const Duration(milliseconds: 600));
    await _handleUri(uri);
  }

  // ── Core router ───────────────────────────────────────────────────────────
  static Future<void> _handleUri(Uri uri) async {
    final navigator = navigatorKey.currentState;
    if (navigator == null) {
      _pendingLink = uri; // store and retry after login
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _pendingLink = uri; // store and retry after login
      return;
    }

    final segments = uri.pathSegments; // e.g. ['quiz', 'abc123']
    if (segments.isEmpty) return;

    final type = segments[0]; // 'quiz' | 'tournament' | 'battle'
    final id = segments.length > 1 ? segments[1] : '';

    if (id.isEmpty) return;

    switch (type) {
      case 'quiz':
        await _navigateToQuiz(navigator, id);
        break;
      case 'tournament':
        await _navigateToTournament(navigator, id);
        break;
      case 'battle':
        await _navigateToBattle(navigator, id);
        break;
    }
  }

  // ── Quiz navigation ───────────────────────────────────────────────────────
  static Future<void> _navigateToQuiz(NavigatorState nav, String quizId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('quizzes')
          .doc(quizId)
          .get();

      if (!snap.exists) {
        _showSnack('Quiz not found');
        return;
      }

      final data = snap.data()!;
      final isActive = data['isActive'] as bool? ?? true;
      final endAt = (data['endAt'] as Timestamp?)?.toDate();
      final isEnded =
          !isActive || (endAt != null && DateTime.now().isAfter(endAt));

      if (isEnded) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => QuizEndedScreen(quizTitle: data['title'] ?? 'Quiz'),
          ),
        );
        return;
      }

      final startAt =
          (data['startAt'] as Timestamp?)?.toDate() ?? DateTime.now();
      final effectiveEnd =
          endAt ?? DateTime.now().add(const Duration(hours: 1));

      nav.push(
        MaterialPageRoute(
          builder: (_) => QuizRulesScreen(
            startAt: startAt,
            quizType: data['quizType'] ?? 'mcq',
            onConfirmedStart: () {
              nav.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => QuizAttemptScreen(
                    quizId: quizId,
                    endAt: effectiveEnd,
                    isDaily: false,
                    topicTitle: data['title'] ?? 'Quiz',
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      _showSnack('Error opening quiz: $e');
    }
  }

  // ── Tournament navigation ─────────────────────────────────────────────────
  static Future<void> _navigateToTournament(
    NavigatorState nav,
    String id,
  ) async {
    try {
      final tournament = await TournamentService.fetchTournament(id);
      if (tournament == null) {
        _showSnack('Tournament not found');
        return;
      }
      nav.push(
        MaterialPageRoute(
          builder: (_) => TournamentDetailScreen(tournament: tournament),
        ),
      );
    } catch (e) {
      _showSnack('Error opening tournament: $e');
    }
  }

  // ── Battle navigation (existing logic preserved) ──────────────────────────
  static Future<void> _navigateToBattle(
    NavigatorState nav,
    String battleId,
  ) async {
    try {
      final battle = await BattleV2Service.fetchBattle(battleId);
      if (battle == null) return;

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (battle.isWaiting && battle.hostId != uid) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => BattleHomeScreen(initialBattleId: battleId),
          ),
        );
      } else if (battle.isActive) {
        nav.push(
          MaterialPageRoute(
            builder: (_) => BattleActiveScreen(battleId: battleId),
          ),
        );
      }
    } catch (_) {}
  }

  static void _showSnack(String msg) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// // ═══════════════════════════════════════════════════════════════════════════════
// // SETUP SNIPPETS — copy these into the right files
// // ═══════════════════════════════════════════════════════════════════════════════

// /*
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  1. pubspec.yaml  — add under dependencies:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

//   app_links: ^6.3.2


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  2. main.dart  — replace your existing main() body
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   await DeepLinkHandler.init();          // ← ADD THIS
//   runApp(const ProviderScope(child: QuizApp()));
// }

// // In MaterialApp, use DeepLinkHandler.navigatorKey:
// MaterialApp(
//   navigatorKey: DeepLinkHandler.navigatorKey,   // ← REPLACE existing navigatorKey
//   ...
// )

// // In AuthWrapper, after confirming user is logged in, add:
// await DeepLinkHandler.processPendingLink();     // ← ADD THIS


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  3. android/app/src/main/AndroidManifest.xml
//     Add INSIDE the existing <activity> tag,
//     after the existing intent-filter block:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// <intent-filter android:autoVerify="true">
//     <action android:name="android.intent.action.VIEW" />
//     <category android:name="android.intent.category.DEFAULT" />
//     <category android:name="android.intent.category.BROWSABLE" />

//     <!-- Handles https://quizaura.netlify.app/quiz/...
//                   https://quizaura.netlify.app/tournament/...
//                   https://quizaura.netlify.app/battle/...       -->
//     <data
//         android:scheme="https"
//         android:host="quizaura.netlify.app" />
// </intent-filter>

// <!-- Custom app:// scheme fallback (works without domain verification) -->
// <intent-filter>
//     <action android:name="android.intent.action.VIEW" />
//     <category android:name="android.intent.category.DEFAULT" />
//     <category android:name="android.intent.category.BROWSABLE" />
//     <data android:scheme="quizaura" android:host="open" />
// </intent-filter>


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  4. ios/Runner/Info.plist  — add these two blocks:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// <!-- Custom URL scheme (quizaura://open/...) -->
// <key>CFBundleURLTypes</key>
// <array>
//   <dict>
//     <key>CFBundleTypeRole</key>
//     <string>Editor</string>
//     <key>CFBundleURLSchemes</key>
//     <array>
//       <string>quizaura</string>
//     </array>
//   </dict>
// </array>

// <!-- Universal Links domain -->
// <key>com.apple.developer.associated-domains</key>
// <array>
//   <string>applinks:quizaura.netlify.app</string>
// </array>


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  5. netlify/public/.well-known/apple-app-site-association
//     Create this file on Netlify for iOS Universal Links:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// {
//   "applinks": {
//     "apps": [],
//     "details": [
//       {
//         "appID": "TEAMID.com.example.quizApp",
//         "paths": ["/quiz/*", "/tournament/*", "/battle/*"]
//       }
//     ]
//   }
// }

// Replace TEAMID with your Apple Team ID (found in developer.apple.com).
// Replace com.example.quizApp with your actual iOS bundle ID
// (check ios/Runner.xcodeproj or Info.plist → CFBundleIdentifier).


// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  6. netlify/public/.well-known/assetlinks.json
//     Create this for Android App Links verification:
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

// [{
//   "relation": ["delegate_permission/common.handle_all_urls"],
//   "target": {
//     "namespace": "android_app",
//     "package_name": "com.example.quiz_app",
//     "sha256_cert_fingerprints": [
//       "YOUR_SHA256_SIGNING_CERT_FINGERPRINT"
//     ]
//   }
// }]

// Get your SHA-256 fingerprint by running:
//   keytool -list -v -keystore your-release-key.jks -alias your-alias

// */