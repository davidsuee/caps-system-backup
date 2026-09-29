import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/presentation/admin/providers/admin_provider.dart';
import 'package:gym_management_system/presentation/admin/screens/admin_dashboard_screen.dart';
import 'package:gym_management_system/presentation/admin/screens/admin_members_directory_screen.dart';

class MockAdminNotifier extends AdminNotifier {
  final List<UserModel> mockMembers;
  final List<MembershipModel> mockMemberships;

  MockAdminNotifier(this.mockMembers, this.mockMemberships);

  @override
  AdminState build() {
    return AdminState(
      isLoading: false,
      members: mockMembers,
      memberships: mockMemberships,
    );
  }
}

void main() {
  testWidgets('AdminDashboardScreen renders with pending membership without layout errors', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final member = UserModel(
      id: 'pending_user_01',
      name: 'Juan Dela Cruz The Third Super Long Name',
      email: 'juan_long_email_address_test@example.com',
      role: UserRole.member,
      fitnessGoal: 'Muscle Gain',
      heightCm: 175,
      weightKg: 70,
      createdAt: DateTime.now(),
    );

    final pending = MembershipModel(
      id: 'mem_pending_01',
      userId: 'pending_user_01',
      planName: 'VIP All-Access Pass (Long Name)',
      price: 2800,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      status: MembershipStatus.pending,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNotifierProvider.overrideWith(() => MockAdminNotifier([member], [pending])),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Pending Cash Approvals'), findsOneWidget);
  });

  testWidgets('AdminDashboardScreen and AdminMembersDirectoryScreen render 12 members with mixed membership states without any Unexpected null value exceptions', (tester) async {
    // Set a large viewport so all 12 items are rendered and laid out completely
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    // Generate exactly 12 members with various status states
    final members = List.generate(12, (i) {
      return UserModel(
        id: 'member_$i',
        name: 'Member $i Number',
        email: 'member$i@example.com',
        role: UserRole.member,
        fitnessGoal: 'Goal $i',
        heightCm: 170.0 + i,
        weightKg: 65.0 + i,
        createdAt: DateTime.now().subtract(Duration(days: i * 5)),
      );
    });

    final memberships = <MembershipModel>[
      // 0-1: Pending memberships
      MembershipModel(
        id: 'mem_0',
        userId: 'member_0',
        planName: 'Monthly Standard',
        price: 1500,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      ),
      MembershipModel(
        id: 'mem_1',
        userId: 'member_1',
        planName: 'Student Pass',
        price: 999,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.pending,
      ),
      // 2-5: Active memberships
      MembershipModel(
        id: 'mem_2',
        userId: 'member_2',
        planName: 'Quarterly Pro',
        price: 4000,
        startDate: DateTime.now().subtract(const Duration(days: 10)),
        endDate: DateTime.now().add(const Duration(days: 80)),
        status: MembershipStatus.active,
      ),
      // 6-8: Expired memberships
      MembershipModel(
        id: 'mem_6',
        userId: 'member_6',
        planName: 'Old Pass',
        price: 1500,
        startDate: DateTime.now().subtract(const Duration(days: 60)),
        endDate: DateTime.now().subtract(const Duration(days: 30)),
        status: MembershipStatus.expired,
      ),
      // 9-11: No membership at all (null)
    ];

    // Test AdminDashboardScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNotifierProvider.overrideWith(() => MockAdminNotifier(members, memberships)),
        ],
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Members Directory (12)'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Test AdminMembersDirectoryScreen
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNotifierProvider.overrideWith(() => MockAdminNotifier(members, memberships)),
        ],
        child: const MaterialApp(
          home: AdminMembersDirectoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Members Records'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminDashboardScreen renders with real AdminNotifier and refreshes without error', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });
}
