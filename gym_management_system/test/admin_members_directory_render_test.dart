import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/presentation/admin/providers/admin_provider.dart';
import 'package:gym_management_system/presentation/admin/screens/admin_members_directory_screen.dart';

class MockAdminDirNotifier extends AdminNotifier {
  final List<UserModel> mockMembers;
  final List<MembershipModel> mockMemberships;

  MockAdminDirNotifier(this.mockMembers, this.mockMemberships);

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
  testWidgets('AdminMembersDirectoryScreen renders with pending filter and approving cash', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final pendingUser = UserModel(
      id: 'pending_user_99',
      name: 'Maria Santos Super Long Name Customer',
      email: 'maria.santos.test@gym.ph',
      role: UserRole.member,
      fitnessGoal: 'Weight Loss and Toning',
      heightCm: 162,
      weightKg: 65,
      createdAt: DateTime.now(),
    );

    final pendingMembership = MembershipModel(
      id: 'mem_pending_99',
      userId: 'pending_user_99',
      planName: 'VIP All-Access Pass',
      price: 2800,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      status: MembershipStatus.pending,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNotifierProvider.overrideWith(() => MockAdminDirNotifier([pendingUser], [pendingMembership])),
        ],
        child: const MaterialApp(
          home: AdminMembersDirectoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify header and filter tab count
    expect(find.text('Members Records'), findsOneWidget);
    expect(find.text('Pending Cash (1)'), findsOneWidget);
    expect(find.text('Confirm Cash Received & Activate (VIP All-Access Pass)'), findsOneWidget);

    // 2. Tap on Pending Cash filter
    await tester.tap(find.text('Pending Cash (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Maria Santos Super Long Name Customer'), findsOneWidget);
  });
}
