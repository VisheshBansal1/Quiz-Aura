import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  // ✅ FIX: All three fields are `late` so they are only constructed
  // when first accessed (i.e. when a login method is actually called),
  // not on AuthService() construction. This prevents the
  // "No Firebase App [DEFAULT]" crash that happens when LoginScreen
  // creates AuthService() before Firebase.initializeApp() completes.
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFirestore _db = FirebaseFirestore.instance;

  // `late` also prevents the google_sign_in_web assertion crash on web.
  // On web, loginWithGoogle() uses signInWithPopup() and never accesses
  // _googleSignIn, so its constructor never runs.
  late final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    String email,
    String password,
    String name,
  ) async {
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
      // ===== WEB =====
      // signInWithPopup opens a Google sign-in popup window.
      // _googleSignIn is never accessed here so its lazy constructor
      // never fires on web (avoids the ClientID assertion crash).
      //
      // REQUIREMENT: Your Google account must be added as a test user in
      // Google Cloud Console → APIs & Services → OAuth consent screen
      // → Test users, OR publish the app.
      // Without this, the popup/redirect shows a blank page.
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCred = await _auth.signInWithPopup(
          googleProvider,
        );
        final user = userCred.user!;
        await _saveUser(user);
        return user;
      }

      // ===== ANDROID / IOS =====
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final UserCredential userCred = await _auth.signInWithCredential(
        credential,
      );

      final user = userCred.user!;
      await _saveUser(user, name: googleUser.displayName);
      return user;
    } catch (e) {
      throw Exception('Google login failed: $e');
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    // Guard: never access _googleSignIn on web — its lazy constructor
    // would throw the ClientID assertion error.
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // ================= AUTH STATE =================
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // ================= ERROR MAPPING =================
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
