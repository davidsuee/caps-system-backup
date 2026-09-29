import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/datasources/remote/firestore_service.dart';
import 'package:gym_management_system/data/repositories/auth_repository_impl.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';

void main() {
  group('Firebase Auth & Error Propagation Tests', () {
    test('signUpWithEmailPassword propagates Firebase error and does not silently swallow it', () async {
      final repo = AuthRepositoryImpl(
        localCache: LocalCacheService(),
      );

      // Attempting to sign up with an already existing email (e.g. florendoreynard4@gmail.com)
      // must throw an exception containing the clear user-friendly message, NOT silently succeed!
      expect(
        () async => await repo.signUpWithEmailPassword(
          name: 'Reynard Duplicate',
          email: 'florendoreynard4@gmail.com',
          password: 'Password123!',
          role: UserRole.member,
          age: 24,
          heightCm: 172,
          weightKg: 68,
          gender: 'Male',
          fitnessGoal: 'Muscle Gain',
          activityLevel: 'Moderately Active',
          experienceLevel: 'Intermediate',
        ),
        throwsA(
          predicate((e) =>
              e.toString().contains('already registered') ||
              e.toString().contains('EMAIL_EXISTS')),
        ),
      );
    });

    test('Firestore serialization roundtrip encodes and decodes types correctly', () {
      final input = {
        'id': 'user_test_999',
        'name': 'Juan Dela Cruz',
        'age': 25,
        'heightCm': 175.5,
        'isActive': true,
        'goals': ['Muscle Gain', 'Endurance'],
        'details': {'tier': 'Gold', 'points': 100},
      };

      final encoded = FirestoreService.encodeMap(input);
      expect(encoded['name']['stringValue'], equals('Juan Dela Cruz'));
      expect(encoded['age']['integerValue'], equals('25'));
      expect(encoded['heightCm']['doubleValue'], equals(175.5));
      expect(encoded['isActive']['booleanValue'], isTrue);
      expect(encoded['goals']['arrayValue']['values'], isNotEmpty);

      final decoded = FirestoreService.decodeMap(encoded);
      expect(decoded['id'], equals('user_test_999'));
      expect(decoded['name'], equals('Juan Dela Cruz'));
      expect(decoded['age'], equals(25));
      expect(decoded['heightCm'], equals(175.5));
      expect(decoded['isActive'], isTrue);
      expect(decoded['goals'], equals(['Muscle Gain', 'Endurance']));
    });
  });
}
