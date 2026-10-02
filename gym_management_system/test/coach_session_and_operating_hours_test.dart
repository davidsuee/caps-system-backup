import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/core/constants/app_strings.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/repositories/coach_repository_impl.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Operating Hours & Coach Capacity Enforcement Tests', () {
    late CoachRepositoryImpl coachRepo;
    late LocalCacheService localCache;

    setUp(() {
      localCache = LocalCacheService();
      coachRepo = CoachRepositoryImpl(localCache: localCache);
    });

    test('Operating Hours constants are set to 8:00 AM – 11:00 PM Daily', () {
      expect(AppStrings.operatingHours, '8:00 AM – 11:00 PM Daily');
      expect(AppStrings.openHour, 8);
      expect(AppStrings.closeHour, 23);
    });

    test('All seeded facilities have operating hours 8:00 AM - 11:00 PM', () {
      final facilities = localCache.getAllFacilities();
      expect(facilities.isNotEmpty, isTrue);
      for (final fac in facilities) {
        expect(fac.operatingHours, '8:00 AM - 11:00 PM');
      }
    });

    test('Rejects training session scheduled before 8:00 AM (e.g., 7:30 AM)', () async {
      final sessionEarly = TrainingSessionModel(
        id: 'test_session_early',
        coachId: 'coach_demo_01',
        coachName: 'Coach Marcus Vance',
        memberId: 'member_seed_01',
        memberName: 'Sarah Jenkins',
        dateTime: DateTime(2026, 10, 1, 7, 30), // 7:30 AM (outside hours)
        focus: 'Strength & Technique Coaching',
        status: 'Confirmed',
      );

      expect(
        () => coachRepo.scheduleSession(sessionEarly),
        throwsA(isA<Exception>()),
      );
    });

    test('Rejects training session scheduled after 11:00 PM (e.g., 11:05 PM)', () async {
      final sessionLate = TrainingSessionModel(
        id: 'test_session_late',
        coachId: 'coach_demo_01',
        coachName: 'Coach Marcus Vance',
        memberId: 'member_seed_01',
        memberName: 'Sarah Jenkins',
        dateTime: DateTime(2026, 10, 1, 23, 5), // 11:05 PM (outside hours)
        focus: 'Strength & Technique Coaching',
        status: 'Confirmed',
      );

      expect(
        () => coachRepo.scheduleSession(sessionLate),
        throwsA(isA<Exception>()),
      );
    });

    test('Allows training session scheduled within 8:00 AM – 11:00 PM', () async {
      final sessionValid = TrainingSessionModel(
        id: 'test_session_valid',
        coachId: 'coach_demo_01',
        coachName: 'Coach Marcus Vance',
        memberId: 'member_seed_01',
        memberName: 'Sarah Jenkins',
        dateTime: DateTime(2026, 10, 1, 10, 0), // 10:00 AM (within hours)
        focus: 'Strength & Technique Coaching',
        status: 'Confirmed',
      );

      await coachRepo.scheduleSession(sessionValid);
      final sessions = await coachRepo.getCoachSessions('coach_demo_01');
      expect(sessions.any((s) => s.id == 'test_session_valid'), isTrue);

      // Test session cancellation
      await coachRepo.cancelSession('test_session_valid');
      final afterCancel = await coachRepo.getCoachSessions('coach_demo_01');
      expect(afterCancel.any((s) => s.id == 'test_session_valid'), isFalse);
    });

    test('Coach assigned clients are strictly capped at max capacity (max 20 clients)', () {
      final coach = localCache.getUserById('coach_demo_01');
      expect(coach, isNotNull);
      localCache.setCurrentUser(coach!);

      // Artificially assign 25 members to this coach in cache
      for (int i = 0; i < 25; i++) {
        final dummy = UserModel(
          id: 'dummy_member_$i',
          name: 'Dummy Member $i',
          email: 'dummy$i@gym.com',
          role: UserRole.member,
          assignedCoachId: 'coach_demo_01',
          createdAt: DateTime.now(),
        );
        localCache.saveUser(dummy);
      }

      // Retrieve cached assigned clients
      final assigned = coachRepo.getCachedAssignedClients();

      // Must be strictly capped at 20!
      expect(assigned.length, lessThanOrEqualTo(20));
      for (final m in assigned) {
        expect(m.assignedCoachId, equals('coach_demo_01'));
      }
    });

    test('Member check-in at 10:00 PM automatically checks out when time reaches 11:00 PM', () {
      // Create a member who checked in at 10:00 PM (22:00) today
      final checkInDate = DateTime(2026, 10, 1, 22, 0); // 10:00 PM
      final att = AttendanceModel(
        id: 'session_10pm',
        userId: 'member_seed_01',
        checkInTime: checkInDate,
        checkOutTime: null, // Still active
      );
      localCache.addAttendance(att);

      // Verify active before closing time (e.g. at 10:45 PM)
      final timeAt1045PM = DateTime(2026, 10, 1, 22, 45);
      localCache.autoCheckOutClosedSessions(timeAt1045PM);
      final activeAt1045 = localCache.getActiveAttendance('member_seed_01');
      expect(activeAt1045, isNotNull);
      expect(activeAt1045?.checkOutTime, isNull);

      // Simulate clock reaching 11:00 PM (23:00)
      final timeAt11PM = DateTime(2026, 10, 1, 23, 0);
      final changed = localCache.autoCheckOutClosedSessions(timeAt11PM);
      expect(changed, isTrue);

      // Verify member is now automatically checked out
      final activeAt11PM = localCache.getActiveAttendance('member_seed_01');
      expect(activeAt11PM, isNull);

      // Verify checkout timestamp is set to exactly 11:00 PM closing time
      final attendanceList = localCache.getAttendance('member_seed_01');
      final record = attendanceList.firstWhere((a) => a.id == 'session_10pm');
      expect(record.checkOutTime, isNotNull);
      expect(record.checkOutTime?.hour, equals(23));
      expect(record.checkOutTime?.minute, equals(0));
    });
  });
}
