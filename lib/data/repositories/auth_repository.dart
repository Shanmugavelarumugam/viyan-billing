import '../../features/auth/services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuthService _authService;

  AuthRepository(this._authService);

  Stream<User?> get authStateChanges => _authService.authStateChanges;
  
  User? get currentUser => _authService.currentUser;

  Future<void> login(String email, String password) => 
      _authService.signInWithEmailAndPassword(email, password);

  Future<void> signup(String email, String password) => 
      _authService.createUserWithEmailAndPassword(email, password);

  Future<void> updateDisplayName(String name) => 
      _authService.updateDisplayName(name);

  Future<void> resetPassword(String email) => 
      _authService.sendPasswordResetEmail(email);

  Future<void> logout() => _authService.signOut();
}
