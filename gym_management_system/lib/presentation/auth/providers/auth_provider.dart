import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/repositories/auth_repository.dart';
import '../../../data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl();
});

class AuthState {
  final UserEntity? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  AuthState copyWith({
    UserEntity? user,
    bool? isLoading,
    String? errorMessage,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late AuthRepository _repo;

  @override
  AuthState build() {
    _repo = ref.read(authRepositoryProvider);
    Future.microtask(checkCurrentUser);
    return const AuthState();
  }

  Future<void> checkCurrentUser() async {
    try {
      final u = await _repo.getCurrentUser();
      if (u != null) {
        state = state.copyWith(user: u);
      }
    } catch (_) {}
  }

  Future<UserEntity?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final u = await _repo.signInWithEmailPassword(email, password);
      state = state.copyWith(user: u, isLoading: false);
      return u;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return null;
    }
  }

  Future<UserEntity?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    required int age,
    required double heightCm,
    required double weightKg,
    required String gender,
    required String fitnessGoal,
    required String activityLevel,
    required String experienceLevel,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final u = await _repo.signUpWithEmailPassword(
        name: name,
        email: email,
        password: password,
        role: role,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg,
        gender: gender,
        fitnessGoal: fitnessGoal,
        activityLevel: activityLevel,
        experienceLevel: experienceLevel,
      );
      state = state.copyWith(user: u, isLoading: false);
      return u;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _repo.signOut();
    } catch (_) {} finally {
      state = const AuthState();
    }
  }

  Future<void> updateProfile(UserEntity updated) async {
    state = state.copyWith(isLoading: true);
    await _repo.updateUserProfile(updated);
    state = state.copyWith(user: updated, isLoading: false);
  }
}

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
