import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_auth_service.dart';
import '../../../data/repositories/auth_repository.dart';

final firebaseAuthProvider = Provider((ref) => FirebaseAuthService());
final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(firebaseAuthProvider)));

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository) : super(AuthState.initial()) {
    _authRepository.authStateChanges.listen((user) {
      if (user != null) {
        state = state.copyWith(
          isAuthenticated: true,
          email: user.email,
          fullName: user.displayName ?? 'User',
        );
      } else {
        state = AuthState.initial();
      }
    });
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.login(email, password);
      final user = _authRepository.currentUser;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        email: email,
        fullName: user?.displayName ?? 'User',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required String language,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.signup(email, password);
      await _authRepository.updateDisplayName(fullName);
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        email: email,
        fullName: fullName,
        preferredLanguage: language,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.resetPassword(email);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = AuthState.initial();
  }
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final String? email;
  final String? fullName;
  final String? preferredLanguage;

  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.email,
    this.fullName,
    this.preferredLanguage,
  });

  factory AuthState.initial() => AuthState(
        isLoading: false,
        isAuthenticated: false,
      );

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? email,
    String? fullName,
    String? preferredLanguage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
    );
  }
}
