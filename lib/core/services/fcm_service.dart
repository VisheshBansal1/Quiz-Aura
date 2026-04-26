import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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

    // FIX: Register background handler BEFORE any other FCM setup.
    // The handler must be a top-level function (it is).
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
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
      debugPrint('[FCM] Token save failed: $e');
    }
  }

  static Future<void> _persistToken(String uid, String token) async {
    await _db.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Write a notification record to Firestore for the target user.
  static Future<void> createNotification({
    required String targetUid,
    required String title,
    required String body,
    required String type,
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

/// Top-level FCM background handler.
/// FIX: Must call Firebase.initializeApp() because background messages
/// run in a SEPARATE Dart isolate where Firebase is not initialized.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FIX: Initialize Firebase in the background isolate if not already done.
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialized — safe to ignore.
  }
  debugPrint('[FCM] Background: ${message.notification?.title}');
}
