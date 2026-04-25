import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  // Check if Firebase is initialized safely
  bool get isInitialized {
    try {
      Firebase.app();
      return true;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth? get _auth {
    if (!isInitialized) return null;
    return FirebaseAuth.instance;
  }

  // Get current user
  User? get currentUser => _auth?.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? Stream.value(null);

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    final auth = _auth;
    if (auth == null) throw Exception('Firebase not initialized.');
    try {
      return await auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign up with email and password
  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    final auth = _auth;
    if (auth == null) throw Exception('Firebase not initialized.');
    try {
      return await auth.createUserWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth?.signOut();
  }

  // Password reset
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _auth;
    if (auth == null) throw Exception('Firebase not initialized.');
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update display name
  Future<void> updateDisplayName(String fullName) async {
    final auth = _auth;
    if (auth == null) throw Exception('Firebase not initialized.');
    try {
      await auth.currentUser?.updateDisplayName(fullName);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials or register first.';
      case 'email-already-in-use':
        return 'The account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'The password is too weak.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}
