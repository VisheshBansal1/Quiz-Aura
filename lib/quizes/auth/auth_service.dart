import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= SAVE USER =================
  Future<void> _saveUser(User user, {String? name}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();

    if (!snap.exists) {
      // 🆕 First time user
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

  // ================= LOGIN GOOGLE =================
  Future<User> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      await googleSignIn.signOut(); // 🔒 force fresh login

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("Google sign-in cancelled");
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      final user = userCred.user!;

      await _saveUser(user, name: googleUser.displayName);

      return user;
    } catch (e) {
      throw Exception("Google login failed");
    }
  }

  // ================= LOGOUT =================
  Future<void> logout() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  // ================= AUTH STATE =================
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // ================= ERROR MAPPING =================
  Exception _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return Exception("User not found");
      case 'wrong-password':
        return Exception("Incorrect password");
      case 'email-already-in-use':
        return Exception("Email already registered");
      case 'invalid-email':
        return Exception("Invalid email address");
      case 'weak-password':
        return Exception("Password is too weak");
      case 'network-request-failed':
        return Exception("No internet connection");
      default:
        return Exception("Authentication failed");
    }
  }
}
