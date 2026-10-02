import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/models/walk_in_record_model.dart';
import 'package:gym_management_system/presentation/admin/providers/admin_provider.dart';
import 'package:gym_management_system/presentation/auth/screens/register_screen.dart';
import 'package:gym_management_system/presentation/landing/screens/membership_tiers_screen.dart';

void main() {
  group('Walk-In Day Pass Admin-Only Workflow Tests', () {
    late LocalCacheService localCache;

    setUp(() {
      localCache = LocalCacheService();
    });

    test('WalkInRecordModel serialization, duration, and copyWith', () {
      final checkIn = DateTime(2026, 10, 1, 9, 0);
      final checkOut = DateTime(2026, 10, 1, 10, 30);

      final record = WalkInRecordModel(
        id: 'walkin_test_01',
        guestName: 'Pedro Santos',
        contactNumber: '09171234567',
        amountPaid: 150.0,
        paymentMethod: 'Cash',
        checkInTime: checkIn,
        checkOutTime: checkOut,
        notes: 'Locker #05',
      );

      expect(record.isActive, isFalse);
      expect(record.formattedDuration, '1h 30m');

      final json = record.toJson();
      expect(json['id'], 'walkin_test_01');
      expect(json['guestName'], 'Pedro Santos');
      expect(json['amountPaid'], 150.0);

      final fromJson = WalkInRecordModel.fromJson(json);
      expect(fromJson.guestName, 'Pedro Santos');
      expect(fromJson.contactNumber, '09171234567');
      expect(fromJson.paymentMethod, 'Cash');
    });

    test('LocalCacheService records walk-ins without user account and integrates with attendance', () {
      final now = DateTime.now();
      final record = WalkInRecordModel(
        id: 'walkin_${now.millisecondsSinceEpoch}',
        guestName: 'Maria Clara',
        contactNumber: '09189876543',
        amountPaid: 150.0,
        paymentMethod: 'Cash at Counter',
        checkInTime: now,
        notes: 'Locker #12',
      );

      // Log walk-in record
      localCache.logWalkInRecord(record);

      final allWalkIns = localCache.getAllWalkInRecords();
      expect(allWalkIns.any((w) => w.id == record.id), isTrue);

      final activeWalkIns = localCache.getActiveWalkInRecords();
      expect(activeWalkIns.any((w) => w.id == record.id), isTrue);

      // Verify it appears in attendance as isWalkIn without requiring an account
      final allAttendance = localCache.getAllAttendance();
      final attMatch = allAttendance.where((a) => a.userId == record.id).firstOrNull;
      expect(attMatch, isNotNull);
      expect(attMatch!.isWalkIn, isTrue);
      expect(attMatch.guestName, 'Maria Clara');
      expect(attMatch.amountPaid, 150.0);
      expect(attMatch.checkOutTime, isNull);

      // Check-out the walk-in
      localCache.checkOutWalkInRecord(record.id);

      // Verify active status updated
      final updatedWalkIns = localCache.getActiveWalkInRecords();
      expect(updatedWalkIns.any((w) => w.id == record.id), isFalse);

      final updatedAttendance = localCache.getAllAttendance();
      final updatedAtt = updatedAttendance.firstWhere((a) => a.userId == record.id);
      expect(updatedAtt.checkOutTime, isNotNull);
    });

    test('AdminNotifier logs walk-in without user account and handles checkout', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(adminNotifierProvider.notifier);
      final initialState = container.read(adminNotifierProvider);
      final initialWalkInCount = initialState.walkIns.length;

      // Log a new walk-in guest at front desk
      final success = await notifier.logWalkIn(
        guestName: 'Roberto Gomez',
        contactNumber: '09191234567',
        amountPaid: 150.0,
        paymentMethod: 'Cash',
        notes: 'Locker #42',
      );
      expect(success, isTrue);

      final stateAfterLog = container.read(adminNotifierProvider);
      expect(stateAfterLog.walkIns.any((w) => w.guestName == 'Roberto Gomez'), isTrue);

      final logged = stateAfterLog.walkIns.where((w) => w.guestName == 'Roberto Gomez').firstOrNull;
      expect(logged, isNotNull);
      expect(logged!.amountPaid, 150.0);
      expect(logged.paymentMethod, 'Cash');
      expect(logged.isActive, isTrue);

      // Verify attendance has walk-in entry without user account
      final attMatch = stateAfterLog.attendance.where((a) => a.userId == logged.id).firstOrNull;
      expect(attMatch, isNotNull);
      expect(attMatch!.isWalkIn, isTrue);
      expect(attMatch.guestName, 'Roberto Gomez');
      expect(attMatch.amountPaid, 150.0);

      // Check-out the walk-in guest
      final checkOutSuccess = await notifier.checkOutWalkIn(logged.id);
      expect(checkOutSuccess, isTrue);

      final stateAfterCheckout = container.read(adminNotifierProvider);
      final updatedWalkIn = stateAfterCheckout.walkIns.firstWhere((w) => w.id == logged.id);
      expect(updatedWalkIn.isActive, isFalse);
      expect(updatedWalkIn.checkOutTime, isNotNull);
    });

    testWidgets('RegisterScreen does not offer Day Pass; shows Walk-In Front Desk notice', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: RegisterScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Fill Account Credentials
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Test WalkIn');
      await tester.enterText(textFields.at(1), 'walkin@test.com');
      await tester.enterText(textFields.at(2), 'password123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Continue to Step 2: Biometrics & Goals'));
      await tester.pumpAndSettle();

      // Step 2: Select Gender & Fill Biometrics
      await tester.ensureVisible(find.text('Male'));
      await tester.tap(find.text('Male'));
      await tester.pumpAndSettle();

      final biometricsFields = find.byType(TextField);
      await tester.ensureVisible(biometricsFields.at(0));
      await tester.enterText(biometricsFields.at(0), '26');
      await tester.ensureVisible(biometricsFields.at(1));
      await tester.enterText(biometricsFields.at(1), '170');
      await tester.ensureVisible(biometricsFields.at(2));
      await tester.enterText(biometricsFields.at(2), '68');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Continue to Membership'));
      await tester.tap(find.text('Continue to Membership'));
      await tester.pumpAndSettle();

      // Step 3: Assert Day Pass is NOT an available tier in the registration wizard
      expect(find.text('Day Pass'), findsNothing);

      // Assert the notice explaining walk-ins pay ₱150 at the desk without account is present
      expect(find.textContaining('1-Day Walk-In Pass'), findsOneWidget);
      expect(find.textContaining('no online account registration required'), findsOneWidget);
    });

    testWidgets('MembershipTiersScreen has Front Counter Walk-In Pass banner and no Daily Drop-In plan card', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: MembershipTiersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Drop-In'), findsNothing);
      expect(find.textContaining('1-Day Walk-In Pass • ₱150'), findsOneWidget);
      expect(find.textContaining('NO ACCOUNT REQUIRED'), findsOneWidget);
    });
  });
}
