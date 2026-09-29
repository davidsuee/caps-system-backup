import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:gym_management_system/domain/entities/progress_log_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/repositories/auth_repository_impl.dart';
import 'package:gym_management_system/data/repositories/progress_repository_impl.dart';

void main() {
  group('Progress Tracking & Weigh-in Delta Tests', () {
    late LocalCacheService localCache;
    late AuthRepositoryImpl authRepo;
    late ProgressRepositoryImpl progressRepo;

    setUp(() {
      localCache = LocalCacheService();
      authRepo = AuthRepositoryImpl(localCache: localCache);
      progressRepo = ProgressRepositoryImpl(localCache: localCache);
    });

    test('Registration automatically records initial baseline weigh-in', () async {
      final uniqueEmail = 'progress_${DateTime.now().millisecondsSinceEpoch}@test.com';
      final user = await authRepo.signUpWithEmailPassword(
        name: 'Test Member',
        email: uniqueEmail,
        password: 'Password123!',
        role: UserRole.member,
        age: 24,
        heightCm: 175.0,
        weightKg: 70.0,
        gender: 'Male',
        fitnessGoal: 'Muscle Gain',
        activityLevel: 'Active',
        experienceLevel: 'Beginner',
      );

      final logs = await progressRepo.getProgressLogs(user.id);
      expect(logs, isNotEmpty);
      expect(logs.first.weightKg, equals(70.0));
      expect(logs.first.notes, equals('Initial weigh-in'));
    });

    test('Total change calculation works when user adds new progress weight', () {
      final user = UserModel(
        id: 'user_delta_test',
        name: 'Delta Tester',
        email: 'delta@test.com',
        role: UserRole.member,
        age: 25,
        heightCm: 170.0,
        weightKg: 70.0,
        gender: 'Male',
        fitnessGoal: 'Fat Loss',
        activityLevel: 'Active',
        experienceLevel: 'Intermediate',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      );

      // 1. Initially only 1 log exists (initial weigh-in at 70kg)
      final logs = <ProgressLogEntity>[
        ProgressLogEntity(
          id: const Uuid().v4(),
          userId: user.id,
          date: user.createdAt,
          weightKg: 70.0,
          notes: 'Initial weigh-in',
        ),
      ];

      // Current formula:
      double currentWeight = logs.isNotEmpty ? logs.last.weightKg : user.weightKg;
      double initialWeight = logs.length > 1
          ? logs.first.weightKg
          : (logs.isNotEmpty && logs.first.weightKg != user.weightKg
              ? user.weightKg
              : (logs.isNotEmpty ? logs.first.weightKg : user.weightKg));
      double delta = currentWeight - initialWeight;

      expect(currentWeight, equals(70.0));
      expect(initialWeight, equals(70.0));
      expect(delta, equals(0.0));

      // 2. User inputs a new progress weigh-in of 68.0 kg (lost 2kg)
      logs.add(ProgressLogEntity(
        id: const Uuid().v4(),
        userId: user.id,
        date: DateTime.now(),
        weightKg: 68.0,
        notes: 'Weigh-in week 1',
      ));

      currentWeight = logs.isNotEmpty ? logs.last.weightKg : user.weightKg;
      initialWeight = logs.length > 1
          ? logs.first.weightKg
          : (logs.isNotEmpty && logs.first.weightKg != user.weightKg
              ? user.weightKg
              : (logs.isNotEmpty ? logs.first.weightKg : user.weightKg));
      delta = currentWeight - initialWeight;

      expect(currentWeight, equals(68.0));
      expect(initialWeight, equals(70.0));
      expect(delta, equals(-2.0));

      // 3. User inputs another progress weigh-in of 67.5 kg
      logs.add(ProgressLogEntity(
        id: const Uuid().v4(),
        userId: user.id,
        date: DateTime.now().add(const Duration(days: 7)),
        weightKg: 67.5,
        notes: 'Weigh-in week 2',
      ));

      currentWeight = logs.isNotEmpty ? logs.last.weightKg : user.weightKg;
      initialWeight = logs.length > 1
          ? logs.first.weightKg
          : (logs.isNotEmpty && logs.first.weightKg != user.weightKg
              ? user.weightKg
              : (logs.isNotEmpty ? logs.first.weightKg : user.weightKg));
      delta = currentWeight - initialWeight;

      expect(currentWeight, equals(67.5));
      expect(initialWeight, equals(70.0));
      expect(delta, equals(-2.5));
    });

    test('Edge case: User had no initial log but logged a new weight directly', () {
      final user = UserModel(
        id: 'user_no_init',
        name: 'No Init Tester',
        email: 'noinit@test.com',
        role: UserRole.member,
        age: 25,
        heightCm: 170.0,
        weightKg: 75.0,
        gender: 'Male',
        fitnessGoal: 'Muscle Gain',
        activityLevel: 'Active',
        experienceLevel: 'Intermediate',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      );

      // Only 1 log with a new weight of 78.0 kg
      final logs = <ProgressLogEntity>[
        ProgressLogEntity(
          id: const Uuid().v4(),
          userId: user.id,
          date: DateTime.now(),
          weightKg: 78.0,
          notes: 'New weight entry',
        ),
      ];

      final currentWeight = logs.isNotEmpty ? logs.last.weightKg : user.weightKg;
      final initialWeight = logs.length > 1
          ? logs.first.weightKg
          : (logs.isNotEmpty && logs.first.weightKg != user.weightKg
              ? user.weightKg
              : (logs.isNotEmpty ? logs.first.weightKg : user.weightKg));
      final delta = currentWeight - initialWeight;

      // Delta should accurately compare against the registered baseline weight of 75.0 kg
      expect(currentWeight, equals(78.0));
      expect(initialWeight, equals(75.0));
      expect(delta, equals(3.0));
    });
  });
}
