import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUseCase {
  final AuthRepository repository;
  SignInUseCase(this.repository);

  Future<UserEntity> execute(String email, String password) {
    return repository.signInWithEmailPassword(email, password);
  }
}

class SignUpUseCase {
  final AuthRepository repository;
  SignUpUseCase(this.repository);

  Future<UserEntity> execute({
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
  }) {
    return repository.signUpWithEmailPassword(
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
  }
}
