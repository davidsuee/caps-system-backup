import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/repositories/admin_repository_impl.dart';
import 'package:gym_management_system/data/repositories/coach_repository_impl.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';

void main() {
  group('Dynamic Admin & Coach Repositories Test', () {
    late LocalCacheService localCache;
    late AdminRepositoryImpl adminRepo;
    late CoachRepositoryImpl coachRepo;

    setUp(() {
      localCache = LocalCacheService();
      adminRepo = AdminRepositoryImpl(localCache: localCache);
      coachRepo = CoachRepositoryImpl(localCache: localCache);
    });

    test('Admin repository fetches members and live KPIs dynamically', () async {
      final members = await adminRepo.getAllMembers();
      expect(members.isNotEmpty, isTrue);

      final kpis = await adminRepo.getKpiMetrics();
      expect(kpis.activeMembersCount, greaterThan(0));
      expect(kpis.monthlyRevenue, greaterThan(0));
      expect(kpis.retentionRate, greaterThan(0));

      // Record a new payment dynamically
      final memberId = members.first.id;
      await adminRepo.recordPayment(
        userId: memberId,
        planName: 'VIP All-Access Pass',
        amount: 2800.0,
        durationDays: 30,
      );

      final updatedMemberships = await adminRepo.getAllMemberships();
      final latest = updatedMemberships.firstWhere((m) => m.userId == memberId);
      expect(latest.planName, 'VIP All-Access Pass');
      expect(latest.price, 2800.0);
      expect(latest.isActive, isTrue);
    });

    test('Coach repository loads real assigned clients and routines', () async {
      final coaches = localCache.getUsersByRole(UserRole.coach);
      expect(coaches.isNotEmpty, isTrue);
      localCache.setCurrentUser(coaches.first);
      final clients = await coachRepo.getAssignedClients();
      expect(clients.isNotEmpty, isTrue);
      expect(clients.every((c) => c.role == UserRole.member), isTrue);
    });
  });
}
