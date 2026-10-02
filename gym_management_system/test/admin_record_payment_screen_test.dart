import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/presentation/admin/providers/admin_provider.dart';
import 'package:gym_management_system/presentation/admin/screens/admin_record_payment_screen.dart';

class TestAdminNotifier extends AdminNotifier {
  final List<UserModel> testMembers;
  final List<MembershipModel> testMemberships;
  bool paymentRecorded = false;
  String? recordedUserId;
  String? recordedPlan;
  double? recordedAmount;

  TestAdminNotifier(this.testMembers, this.testMemberships);

  @override
  AdminState build() {
    return AdminState(
      isLoading: false,
      members: testMembers,
      memberships: testMemberships,
    );
  }

  @override
  Future<bool> recordPayment({
    required String userId,
    required String planName,
    required double amount,
    required int durationDays,
  }) async {
    paymentRecorded = true;
    recordedUserId = userId;
    recordedPlan = planName;
    recordedAmount = amount;
    return true;
  }
}

void main() {
  testWidgets('AdminRecordPaymentScreen interactive functional test', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testMember = UserModel(
      id: 'member_001',
      name: 'Sarah Jenkins',
      email: 'sarah.j@example.com',
      role: UserRole.member,
      fitnessGoal: 'Weight Loss',
      heightCm: 165,
      weightKg: 60,
      createdAt: DateTime.now(),
    );

    final testMember2 = UserModel(
      id: 'member_002',
      name: 'Dave Smith',
      email: 'dave@example.com',
      role: UserRole.member,
      fitnessGoal: 'Muscle Gain',
      heightCm: 180,
      weightKg: 80,
      createdAt: DateTime.now(),
    );

    final pending = MembershipModel(
      id: 'mem_pending_dave',
      userId: 'member_002',
      planName: 'Monthly Standard',
      price: 1500,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 30)),
      status: MembershipStatus.pending,
    );

    final testNotifier = TestAdminNotifier([testMember, testMember2], [pending]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminNotifierProvider.overrideWith(() => testNotifier),
        ],
        child: const MaterialApp(
          home: AdminRecordPaymentScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Direct Payment Tab elements render
    expect(find.text('Record Member Payment'), findsOneWidget);
    expect(find.text('Front Desk Reception & Cashier Desk'), findsOneWidget);
    expect(find.text('1. Select Gym Member'), findsOneWidget);
    expect(find.text('2. Select Subscription Tier'), findsOneWidget);
    expect(find.text('3. Payment Method & Cash Tender'), findsOneWidget);

    // Verify initial member is selected
    expect(find.textContaining('Sarah Jenkins'), findsWidgets);

    // Select Monthly Standard plan
    final monthlyStandardFinder = find.text('Monthly Standard');
    expect(monthlyStandardFinder, findsOneWidget);
    await tester.tap(monthlyStandardFinder);
    await tester.pumpAndSettle();

    // Check that total payable updated to ₱1,500
    expect(find.text('₱1,500'), findsWidgets);

    // Verify Confirm & Activate Membership button is present and clickable
    final confirmBtn = find.textContaining('Confirm & Activate Membership');
    expect(confirmBtn, findsOneWidget);

    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify payment was recorded
    expect(testNotifier.paymentRecorded, isTrue);
    expect(testNotifier.recordedUserId, equals('member_001'));
    expect(testNotifier.recordedPlan, equals('Monthly Standard'));
    expect(testNotifier.recordedAmount, equals(1500.0));
  });
}
