import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

/// Handles Firebase Cloud Messaging — token registration, local display,
/// and writing notification records to Firestore.
class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  /// Call once in main() after Firebase.initializeApp().
  static Future<void> init() async {
    // Request permission (iOS + Android 13+)
    await _messaging.requestPermission(alert: true, badge: true, sound: true);

    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      // TODO: Show in-app snackbar/overlay using navigatorKey
    });

    // Save token when user logs in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await saveTokenForUser(user.uid);
    }

    // Refresh token listener
    _messaging.onTokenRefresh.listen((token) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _persistToken(uid, token);
    });
  }

  /// Save FCM token to Firestore (called on login).
  static Future<void> saveTokenForUser(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _persistToken(uid, token);
    } catch (e) {
      // Silently ignored on web or when FCM is unavailable
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  static Future<void> _persistToken(String uid, String token) async {
    // FIX 7: use set(merge:true) — .update() throws if doc doesn't exist yet
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Write a notification record to Firestore for the target user.
  /// The actual push is sent server-side (Cloud Function or Admin SDK).
  static Future<void> createNotification({
    required String targetUid,
    required String title,
    required String body,
    required String type, // 'battle_invite' | 'tournament' | 'result' | 'badge'
    Map<String, dynamic> metadata = const {},
  }) async {
    await _db
        .collection('notifications')
        .doc(targetUid)
        .collection('items')
        .add({
          'title': title,
          'body': body,
          'type': type,
          'read': false,
          'metadata': metadata,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Count unread notifications for badge display.
  static Stream<int> unreadCount(String uid) {
    return _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.length);
  }

  /// Mark all notifications as read.
  static Future<void> markAllRead(String uid) async {
    final batch = _db.batch();
    final snap = await _db
        .collection('notifications')
        .doc(uid)
        .collection('items')
        .where('read', isEqualTo: false)
        .get();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

/// Top-level function required by FCM background handler.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background: ${message.notification?.title}');
}
