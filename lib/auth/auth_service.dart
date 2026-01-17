import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔐 Login with email & password
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  /// 🆕 Register new user
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await cred.user?.sendEmailVerification();
      return cred.user;
    } on FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    }
  }

  Future<User?> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      return userCred.user;
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  /// 🚪 Logout
  Future<void> logout() async {
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// 🔄 Auth state stream
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  /// ❌ Centralized error handling
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
