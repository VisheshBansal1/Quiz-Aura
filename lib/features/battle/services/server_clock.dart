// ============================================================
// FILE: lib/features/battle/services/server_clock.dart
// Estimates this device's offset from the Firebase server clock.
// Used ONLY for display (countdowns, timer bars). Every rule that
// matters (answer windows, stale presence, expiry) is enforced by
// the security rules with request.time, never by this value.
//
// Method: write a serverTimestamp to battlePlayers/{uid} and read
// it back; the stamp was taken around the midpoint of the write.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ServerClock {
  ServerClock._();

  static int _offsetMs = 0;
  static bool _synced = false;
  static int _lastSyncMs = 0;

  static int get nowMs => DateTime.now().millisecondsSinceEpoch + _offsetMs;

  static bool get isSynced => _synced;

  /// Safe to call often: skips if synced in the last 60 s unless [force].
  static Future<void> sync({bool force = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final local = DateTime.now().millisecondsSinceEpoch;
    if (!force && _synced && local - _lastSyncMs < 60000) return;
    try {
      final ref = FirebaseFirestore.instance.collection('battlePlayers').doc(uid);
      final sent = DateTime.now().millisecondsSinceEpoch;
      await ref.set({'ping': FieldValue.serverTimestamp()});
      final acked = DateTime.now().millisecondsSinceEpoch;
      final snap = await ref.get(const GetOptions(source: Source.server));
      final ts = snap.data()?['ping'];
      if (ts is Timestamp) {
        final mid = sent + (acked - sent) ~/ 2;
        _offsetMs = ts.millisecondsSinceEpoch - mid;
        _synced = true;
        _lastSyncMs = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (_) {
      // Offline or rules not deployed yet: keep the previous estimate.
    }
  }
}
