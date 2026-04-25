import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // On web, GoogleSignIn requires clientId explicitly.
  // On Android/iOS it reads from google-services.json / GoogleService-Info.plist.
  // Using the wrong setup on either platform causes silent failures.
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '296193820246-6bqlgd3ss35q0pgclm4c7jj538kq7e4a.apps.googleusercontent.com'
        : null,
  );

  // ================= SAVE USER =================
  Future<void> _saveUser(User user, {String? name}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'name': name ?? user.displayName ?? 'User',
        'provider': user.providerData.first.providerId,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'xp': 0,
        'totalXp': 0,
        'level': 1,
        'requiredXp': 100,
        'streakCount': 0,
        'coins': 0,
        'badges': [],
        'branch': 'CSE',
        'totalQuizzes': 0,
        'weeklyXp': 0,
        'monthlyXp': 0,
        'battleWins': 0,
        'accuracyByTopic': {},
      });
    } else {
      final data = snap.data() ?? {};
      final updates = <String, dynamic>{
        'lastLoginAt': FieldValue.serverTimestamp(),
      };

      if (!data.containsKey('coins')) updates['coins'] = 0;
      if (!data.containsKey('badges')) updates['badges'] = [];
      if (!data.containsKey('branch')) updates['branch'] = 'CSE';
      if (!data.containsKey('totalQuizzes')) updates['totalQuizzes'] = 0;
      if (!data.containsKey('battleWins')) updates['battleWins'] = 0;

      await ref.update(updates);
    }
  }

  // ================= LOGIN EMAIL =================
  Future<User> loginWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      await _saveUser(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // ================= REGISTER EMAIL =================
  Future<User> registerWithEmail(
      String email, String password, String name) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(name);
      await user.sendEmailVerification();
      await _saveUser(user, name: name);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  // ================= GOOGLE LOGIN =================
  Future<User> loginWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser =
          await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCred =
          await _auth.signInWithCredential(credential);

      final user = userCred.user!;
      await _saveUser(user, name: googleUser.displayName);

      return user;
    } catch (e) {
      throw Exception('Google login failed: $e');
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    try {
      await _googleSignIn.signOut(); // ✅ SAME INSTANCE
    } catch (_) {}
    await _auth.signOut();
  }

  // ================= AUTH STATE =================
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Exception _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception('No account found with this email');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'invalid-credential':
        return Exception('Incorrect email or password');
      case 'invalid-email':
        return Exception('Invalid email address');
      case 'email-already-in-use':
        return Exception('Email already registered');
      case 'weak-password':
        return Exception('Password is too weak (min 6 characters)');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'too-many-requests':
        return Exception('Too many attempts. Please try again later');
      case 'network-request-failed':
        return Exception('No internet connection');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }
}