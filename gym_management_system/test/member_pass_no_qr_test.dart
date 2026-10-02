import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/presentation/auth/providers/auth_provider.dart';
import 'package:gym_management_system/presentation/membership/providers/membership_provider.dart';
import 'package:gym_management_system/presentation/membership/screens/attendance_screen.dart';

class MockAuthNotifier extends AuthNotifier {
  final UserModel _mockUser;
  MockAuthNotifier(this._mockUser);

  @override
  AuthState build() {
    return AuthState(user: _mockUser);
  }
}

class MockMembershipNotifier extends MembershipNotifier {
  final MembershipModel _mockMembership;
  MockMembershipNotifier(this._mockMembership);

  @override
  MembershipState build() {
    return MembershipState(
      membership: _mockMembership,
      attendanceHistory: const [],
    );
  }

  @override
  Future<void> loadUserData(String userId) async {
    // No-op to avoid unhandled timers in test
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Member Pass Screen contains NO QR code and NO Scan Turnstile or Time-In buttons', (tester) async {
    final localCache = LocalCacheService();
    final testUser = UserModel(
      id: 'member_8',
      name: 'Sarah Jenkins',
      email: 'sarah.jenkins@example.com',
      role: UserRole.member,
      fitnessGoal: 'Muscle Building',
      experienceLevel: 'Intermediate',
      createdAt: DateTime.now(),
    );
    localCache.saveUser(testUser);

    final membership = MembershipModel(
      id: 'mem_sarah_1',
      userId: testUser.id,
      planName: 'VIP Pro Pass',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
      price: 1500,
      status: MembershipStatus.active,
    );
    localCache.saveMembership(membership);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(() => MockAuthNotifier(testUser)),
          membershipNotifierProvider.overrideWith(() => MockMembershipNotifier(membership)),
        ],
        child: const MaterialApp(
          home: AttendanceScreen(),
        ),
      ),
    );

    await tester.pump();

    // 1. Verify AppBar and Title
    expect(find.text('Digital Member Pass'), findsOneWidget);

    // 2. Strictly verify NO QR code image / widgets exist
    expect(find.textContaining('Scan Turnstile'), findsNothing);
    expect(find.text('Time-In'), findsNothing);
    expect(find.text('Time-Out'), findsNothing);
    expect(find.textContaining('Scan at reception or gym turnstile to log attendance automatically'), findsNothing);

    // 3. Verify Digital Member Pass Content
    expect(find.text('VICIOUS DIGITAL MEMBER PASS'), findsOneWidget);
    expect(find.text('ACTIVE MEMBER'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
    expect(find.text('ID: MEMBER_8'), findsOneWidget);
    expect(find.text('VIP Pro Pass'), findsOneWidget);
    expect(find.text('Front Desk Attendance Logging'), findsOneWidget);
    expect(find.textContaining('Please state your Name or Member ID to the front desk reception upon entry'), findsOneWidget);
    expect(find.text('Facility Hours: 8:00 AM – 11:00 PM Daily'), findsOneWidget);
    expect(find.text('Attendance History'), findsOneWidget);

    // Clean up screen before test end to stop live timer
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
