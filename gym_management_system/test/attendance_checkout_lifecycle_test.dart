import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/repositories/membership_repository_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Attendance Check-In & Check-Out Lifecycle (DFD 4.0)', () {
    late LocalCacheService localCache;
    late MembershipRepositoryImpl membershipRepo;
    const testUserId = 'test_member_checkout_101';

    setUp(() {
      localCache = LocalCacheService();
      membershipRepo = MembershipRepositoryImpl(localCache: localCache);
    });

    test('Initial state: Member has no active check-in', () async {
      final active = await membershipRepo.getActiveAttendance(testUserId);
      expect(active, isNull);
    });

    test('Check-in creates an open session (Time-In recorded, checkOutTime is null)', () async {
      await membershipRepo.logCheckIn(testUserId);

      final active = await membershipRepo.getActiveAttendance(testUserId);
      expect(active, isNotNull);
      expect(active!.userId, testUserId);
      expect(active.checkOutTime, isNull);
      expect(active.status, 'present');

      final history = await membershipRepo.getAttendanceHistory(testUserId);
      expect(history.any((a) => a.id == active.id), isTrue);
    });

    test('Check-out completes session (Time-Out recorded with valid duration)', () async {
      // Perform Check-Out
      await membershipRepo.logCheckOut(testUserId);

      // Verify active attendance is now null
      final active = await membershipRepo.getActiveAttendance(testUserId);
      expect(active, isNull);

      // Verify history contains completed record with checkOutTime
      final history = await membershipRepo.getAttendanceHistory(testUserId);
      final completed = history.firstWhere((a) => a.userId == testUserId);
      expect(completed.checkOutTime, isNotNull);
      expect(completed.checkOutTime!.isAfter(completed.checkInTime) || 
             completed.checkOutTime!.isAtSameMomentAs(completed.checkInTime), isTrue);
    });

    test('Persistence test: Attendance logs persist to SharedPreferences across app restart / re-initialization', () async {
      await membershipRepo.logCheckIn('persist_user_999');
      final active = await membershipRepo.getActiveAttendance('persist_user_999');
      expect(active, isNotNull);

      // Re-initialize LocalCacheService as if app was restarted
      await LocalCacheService.initialize();

      final reloadedAttendance = localCache.getAllAttendance();
      expect(reloadedAttendance.any((a) => a.userId == 'persist_user_999'), isTrue);

      final reloadedActive = localCache.getActiveAttendance('persist_user_999');
      expect(reloadedActive, isNotNull);
      expect(reloadedActive!.userId, equals('persist_user_999'));
    });
  });
}
