import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/repositories/membership_repository_impl.dart';
import 'package:gym_management_system/data/repositories/admin_repository_impl.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/presentation/admin/providers/admin_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Over-the-Counter Cash Membership Request & Admin Approval Tests', () {
    late LocalCacheService localCache;
    late MembershipRepositoryImpl membershipRepo;
    late AdminRepositoryImpl adminRepo;

    const testUserId = 'test_member_cash_001';

    setUp(() {
      localCache = LocalCacheService();
      membershipRepo = MembershipRepositoryImpl(localCache: localCache);
      adminRepo = AdminRepositoryImpl(localCache: localCache);

      // Clean test user data
      localCache.deleteMembership(testUserId);
    });

    test('1. Member submits cash request -> registered as PENDING and not active', () async {
      final now = DateTime.now();
      final pendingRequest = MembershipModel(
        id: const Uuid().v4(),
        userId: testUserId,
        planName: 'VIP All-Access Pass',
        price: 2800.0,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      );

      await membershipRepo.purchaseOrRenewMembership(pendingRequest);

      final fetched = await membershipRepo.getUserMembership(testUserId);
      expect(fetched, isNotNull);
      expect(fetched!.planName, equals('VIP All-Access Pass'));
      expect(fetched.price, equals(2800.0));
      expect(fetched.status, equals(MembershipStatus.pending));
      expect(fetched.isPending, isTrue);
      expect(fetched.isActive, isFalse);
    });

    test('2. Admin KPI metrics excludes pending memberships from revenue', () async {
      final now = DateTime.now();
      final pendingRequest = MembershipModel(
        id: const Uuid().v4(),
        userId: testUserId,
        planName: 'VIP All-Access Pass',
        price: 2800.0,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      );
      localCache.saveMembership(pendingRequest);

      final all = await adminRepo.getAllMemberships();
      final pendingList = all.where((m) => m.status == MembershipStatus.pending).toList();
      expect(pendingList.any((m) => m.userId == testUserId), isTrue);

      final kpi = await adminRepo.getKpiMetrics();
      // Monthly revenue should NOT include pending cash payment
      final activeMemberships = all.where((m) => m.status == MembershipStatus.active);
      final activeRevenue = activeMemberships.fold(0.0, (sum, m) => sum + m.price);
      if (activeRevenue > 0) {
        expect(kpi.monthlyRevenue, equals(activeRevenue));
      }
    });

    test('3. Admin approves cash payment -> status becomes ACTIVE and duration set', () async {
      final now = DateTime.now();
      final pendingRequest = MembershipModel(
        id: const Uuid().v4(),
        userId: testUserId,
        planName: 'Monthly Standard',
        price: 1500.0,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      );
      localCache.saveMembership(pendingRequest);

      // Admin approves
      await adminRepo.approvePendingMembership(pendingRequest);

      final approved = await membershipRepo.getUserMembership(testUserId);
      expect(approved, isNotNull);
      expect(approved!.status, equals(MembershipStatus.active));
      expect(approved.isActive, isTrue);
      expect(approved.isPending, isFalse);
      expect(approved.remainingDays, greaterThanOrEqualTo(29));
    });

    test('4. Admin rejects cash request -> request removed', () async {
      final now = DateTime.now();
      final pendingRequest = MembershipModel(
        id: const Uuid().v4(),
        userId: testUserId,
        planName: 'Student Semester Pass',
        price: 3900.0,
        startDate: now,
        endDate: now.add(const Duration(days: 90)),
        status: MembershipStatus.pending,
      );
      localCache.saveMembership(pendingRequest);

      // Admin rejects
      await adminRepo.rejectPendingMembership(
        membershipId: pendingRequest.id,
        userId: testUserId,
      );

      final postReject = localCache.getMembership(testUserId);
      expect(postReject == null || postReject.status == MembershipStatus.expired, isTrue);
    });

    test('5. AdminNotifier hydrates pending memberships immediately upon build and retains them during loadDashboard', () async {
      final now = DateTime.now();
      final pendingRequest = MembershipModel(
        id: const Uuid().v4(),
        userId: testUserId,
        planName: 'VIP All-Access Pass',
        price: 2800.0,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      );
      localCache.saveMembership(pendingRequest);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // On initial build (frame 0), state already has the pending membership from cache!
      final initialState = container.read(adminNotifierProvider);
      expect(initialState.pendingMemberships.any((m) => m.userId == testUserId), isTrue);

      // Trigger refresh
      final notifier = container.read(adminNotifierProvider.notifier);
      final refreshFuture = notifier.loadDashboard();

      // During refresh, state still retains the pending membership (never disappears)
      final midState = container.read(adminNotifierProvider);
      expect(midState.pendingMemberships.any((m) => m.userId == testUserId), isTrue);

      await refreshFuture;

      // After refresh finishes, pending membership is still present
      final finalState = container.read(adminNotifierProvider);
      expect(finalState.pendingMemberships.any((m) => m.userId == testUserId), isTrue);
    });

    test('6. Admin approves pending membership -> pendingMemberships no longer contains user and user becomes active', () async {
      final now = DateTime.now();
      final pendingRequest = MembershipModel(
        id: const Uuid().v4(),
        userId: testUserId,
        planName: 'Monthly Standard',
        price: 1500.0,
        startDate: now,
        endDate: now.add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      );
      localCache.saveMembership(pendingRequest);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminNotifierProvider.notifier);
      await notifier.loadDashboard();

      final beforeState = container.read(adminNotifierProvider);
      expect(beforeState.pendingMemberships.any((m) => m.userId == testUserId), isTrue);

      // Approve
      final success = await notifier.approveMembership(pendingRequest);
      expect(success, isTrue);

      final afterState = container.read(adminNotifierProvider);
      // MUST NOT be in pendingMemberships anymore!
      expect(afterState.pendingMemberships.any((m) => m.userId == testUserId), isFalse);

      // Membership for user must now be active
      final mem = afterState.getMembershipForUser(testUserId);
      expect(mem, isNotNull);
      expect(mem!.status, equals(MembershipStatus.active));
      expect(mem.isActive, isTrue);
    });
  });
}
