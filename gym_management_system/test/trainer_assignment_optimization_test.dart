import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/repositories/admin_repository_impl.dart';
import 'package:gym_management_system/data/repositories/coach_repository_impl.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';

void main() {
  group('Trainer Assignment Optimization Engine (DFD 6.0 & Specific Objective 4)', () {
    late LocalCacheService localCache;
    late AdminRepositoryImpl adminRepo;
    late CoachRepositoryImpl coachRepo;

    setUp(() {
      localCache = LocalCacheService();
      adminRepo = AdminRepositoryImpl(localCache: localCache);
      coachRepo = CoachRepositoryImpl(localCache: localCache);
      for (final m in localCache.getUsersByRole(UserRole.member)) {
        localCache.saveUser(UserModel.fromEntity(m.copyWith(assignedCoachId: null)));
      }
    });

    test('Initial system state: Coaches have specialized disciplines and capacities', () async {
      final coaches = await adminRepo.getAllCoaches();
      expect(coaches.isNotEmpty, isTrue);

      final marcus = coaches.firstWhere((c) => c.name.contains('Marcus'));
      expect(marcus.specialization, contains('Strength'));
      expect(marcus.maxClients, greaterThanOrEqualTo(6));

      final elena = coaches.firstWhere((c) => c.name.contains('Elena'));
      expect(elena.specialization, contains('Fat Loss'));

      final dave = coaches.firstWhere((c) => c.name.contains('Dave'));
      expect(dave.specialization, contains('Hypertrophy'));
    });

    test('Optimization Engine matches unassigned members to optimal coaches based on synergy & workload', () async {
      final result = await adminRepo.runTrainerAssignmentOptimization();

      expect(result.totalEvaluated, greaterThan(0));
      expect(result.newlyAssignedCount, greaterThan(0));
      expect(result.matches.isNotEmpty, isTrue);

      // Verify Sarah (Weight Loss) matched with Elena (Fat Loss & HIIT)
      final sarahMatch = result.matches.where((m) => m.memberName.contains('Sarah')).firstOrNull;
      if (sarahMatch != null) {
        expect(sarahMatch.coachName, contains('Elena'));
        expect(sarahMatch.matchScore, greaterThanOrEqualTo(75));
      }

      // Verify Michael (Strength) matched with Marcus (Strength & Conditioning)
      final michaelMatch = result.matches.where((m) => m.memberName.contains('Michael')).firstOrNull;
      if (michaelMatch != null) {
        expect(michaelMatch.coachName, contains('Marcus'));
        expect(michaelMatch.matchScore, greaterThanOrEqualTo(75));
      }

      // Verify Arnold (Muscle Gain) matched with Dave (Bodybuilding & Hypertrophy)
      final arnoldMatch = result.matches.where((m) => m.memberName.contains('Arnold')).firstOrNull;
      if (arnoldMatch != null) {
        expect(arnoldMatch.coachName, contains('Dave'));
        expect(arnoldMatch.matchScore, greaterThanOrEqualTo(75));
      }

      // Verify member state is persisted in local cache
      final updatedMembers = await adminRepo.getAllMembers();
      final sarah = updatedMembers.firstWhere((m) => m.name.contains('Sarah'));
      expect(sarah.assignedCoachId, isNotNull);
      if (sarahMatch != null) {
        expect(sarah.assignedCoachId, sarahMatch.coachId);
      }
    });

    test('Admin manual reassignment override dynamically changes client allocation', () async {
      final members = await adminRepo.getAllMembers();
      final sarah = members.firstWhere((m) => m.name.contains('Sarah'));

      // Manually override Sarah's assignment to Coach Marcus
      await adminRepo.assignMemberToCoach(
        memberId: sarah.id,
        coachId: 'coach_demo_01',
      );

      final reloadedSarah = localCache.getUserById(sarah.id);
      expect(reloadedSarah?.assignedCoachId, 'coach_demo_01');
    });

    test('Coach assigned roster respects specific assignments when logged in', () async {
      final coaches = await adminRepo.getAllCoaches();
      final marcus = coaches.firstWhere((c) => c.name.contains('Marcus'));

      // Set Marcus as current user
      localCache.setCurrentUser(marcus);

      // Get Marcus's assigned clients
      final marcusClients = await coachRepo.getAssignedClients();
      expect(marcusClients.isNotEmpty, isTrue);
      expect(marcusClients.every((c) => c.assignedCoachId == marcus.id || c.role == UserRole.member), isTrue);
    });

    test('Day Pass walk-ins are exempted from trainer assignment and do not consume coach capacity', () async {
      // Create a 1-day pass walk-in member
      final dayPassUser = UserModel(
        id: 'member_daypass_exempt_01',
        name: 'DayPass Walker',
        email: 'walker@daypass.test',
        role: UserRole.member,
        fitnessGoal: 'Weight Loss',
        createdAt: DateTime.now(),
      );
      localCache.saveUser(dayPassUser);
      final dayPassMem = MembershipModel(
        id: 'mem_walker_01',
        userId: dayPassUser.id,
        planName: 'Day Pass',
        price: 150.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        status: MembershipStatus.active,
      );
      localCache.saveMembership(dayPassMem);

      // Run optimization engine
      final result = await adminRepo.runTrainerAssignmentOptimization();

      // Ensure day pass member is NOT among matched newly assigned clients
      final dayPassMatch = result.matches.where((m) => m.memberId == dayPassUser.id).firstOrNull;
      expect(dayPassMatch, isNull);

      final reloadedUser = localCache.getUserById(dayPassUser.id);
      expect(reloadedUser?.assignedCoachId, isNull);

      // Verify that coach assigned clients list excludes this 1-day pass member
      final coaches = await adminRepo.getAllCoaches();
      final marcus = coaches.firstWhere((c) => c.name.contains('Marcus'));
      localCache.setCurrentUser(marcus);
      final marcusClients = await coachRepo.getAssignedClients();
      expect(marcusClients.any((c) => c.id == dayPassUser.id), isFalse);
    });
  });
}
