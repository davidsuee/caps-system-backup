import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> getCurrentUser();
  Future<UserEntity> signInWithEmailPassword(String email, String password);
  Future<UserEntity> signUpWithEmailPassword({
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
  });
  Future<void> signOut();
  Future<void> updateUserProfile(UserEntity user);
}
