import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRepository {
  static final _db = FirebaseFirestore.instance;

  static Future<void> saveUser(User user, {String? name}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // 🆕 First time login
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'name': name ?? user.displayName ?? 'User',
        'provider': user.providerData.first.providerId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    } else {
      // 🔁 Existing user
      await ref.update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
