// ============================================================
// FILE: lib/features/battle/services/deep_link_service.dart
// Handles incoming deep links for battle invites.
// Supports:
//   - app://battle/{battleId}
//   - https://quizaura.app/battle/{battleId}
//
// Integration:
//   1. Add to main.dart inside initState of your root widget
//   2. Handles both cold-start and foreground deep links
//
// Android: Add intent-filter in AndroidManifest.xml
// iOS: Add URL scheme + associated domains in Info.plist
// ============================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/battle_home_screen.dart';
import '../screens/battle_active_screen.dart';
import 'battle_v2_service.dart';

class DeepLinkService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Call this from your app's navigatorKey or MaterialApp's navigatorKey.
  /// Pass the full URL received from the platform deep link.
  static Future<void> handleLink(String url) async {
    final battleId = BattleV2Service.parseInviteLink(url);
    if (battleId.isEmpty) return;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    // Ensure user is logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Queue the link to be handled after login
      _pendingBattleId = battleId;
      return;
    }

    await _navigateToBattle(navigator, battleId);
  }

  static String? _pendingBattleId;

  /// Call this after login to process any pending deep link
  static Future<void> processPendingLink() async {
    if (_pendingBattleId == null) return;
    final id = _pendingBattleId!;
    _pendingBattleId = null;

    final navigator = navigatorKey.currentState;
    if (navigator == null) return;
    await _navigateToBattle(navigator, id);
  }

  static Future<void> _navigateToBattle(
      NavigatorState navigator, String battleId) async {
    try {
      final battle = await BattleV2Service.fetchBattle(battleId);
      if (battle == null) return;

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

      if (battle.isWaiting && battle.hostId != uid) {
        // Opponent joining a waiting battle
        navigator.push(MaterialPageRoute(
          builder: (_) => BattleHomeScreen(initialBattleId: battleId),
        ));
      } else if (battle.isActive) {
        // Already active — jump straight into play
        navigator.push(MaterialPageRoute(
          builder: (_) => BattleActiveScreen(battleId: battleId),
        ));
      }
      // If finished or cancelled, no navigation
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANDROID MANIFEST SNIPPET (add inside <activity> tag):
// ─────────────────────────────────────────────────────────────────────────────
/*
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <!-- App scheme (for direct app links) -->
    <data android:scheme="app" android:host="battle" />
    <!-- HTTPS deep link -->
    <data android:scheme="https" android:host="quizaura.app" android:pathPrefix="/battle" />
</intent-filter>
*/

// ─────────────────────────────────────────────────────────────────────────────
// IOS Info.plist SNIPPET:
// ─────────────────────────────────────────────────────────────────────────────
/*
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>app</string>
    </array>
    <key>CFBundleURLName</key>
    <string>com.yourcompany.quizaura</string>
  </dict>
</array>
*/

// ─────────────────────────────────────────────────────────────────────────────
// HOW TO WIRE IN main.dart:
// ─────────────────────────────────────────────────────────────────────────────
/*
// 1. In MaterialApp, pass the navigatorKey:
MaterialApp(
  navigatorKey: DeepLinkService.navigatorKey,
  ...
)

// 2. In your root widget initState, listen for links using uni_links package:
import 'package:uni_links/uni_links.dart';

@override
void initState() {
  super.initState();

  // Cold start link
  getInitialLink().then((link) {
    if (link != null) DeepLinkService.handleLink(link);
  });

  // Foreground links
  linkStream.listen((link) {
    if (link != null) DeepLinkService.handleLink(link);
  });
}

// 3. After login, process any pending link:
await DeepLinkService.processPendingLink();
*/
