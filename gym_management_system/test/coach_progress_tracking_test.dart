import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/data/models/progress_log_model.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/models/workout_plan_model.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/presentation/coach/providers/coach_provider.dart';
import 'package:gym_management_system/presentation/coach/screens/coach_dashboard_screen.dart';

class MockCoachNotifier extends CoachNotifier {
  final List<UserModel> mockClients;
  final Map<String, WorkoutPlanModel?> mockWorkouts;

  MockCoachNotifier(this.mockClients, [this.mockWorkouts = const {}]);

  @override
  CoachState build() {
    return CoachState(
      isLoading: false,
      clients: mockClients,
      clientWorkouts: mockWorkouts,
      clientMeals: const {},
      sessions: const [],
    );
  }
}

void main() {
  testWidgets('Coach Dashboard displays Client Progress Tracking underneath search bar & scope chips', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final localCache = LocalCacheService();

    final clientA = UserModel(
      id: 'client_track_a',
      name: 'Sude Demirtas',
      email: 'sude@test.com',
      role: UserRole.member,
      fitnessGoal: 'Muscle Gain',
      heightCm: 172,
      weightKg: 68.0,
      experienceLevel: 'Beginner',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    final clientB = UserModel(
      id: 'client_track_b',
      name: 'Carla Gomez',
      email: 'carla@test.com',
      role: UserRole.member,
      fitnessGoal: 'Fat Loss',
      heightCm: 162,
      weightKg: 64.0,
      experienceLevel: 'Intermediate',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );

    // Seed progress logs for clientA
    localCache.addProgressLog(ProgressLogModel(
      id: 'log_a_1',
      userId: 'client_track_a',
      date: DateTime.now().subtract(const Duration(days: 7)),
      weightKg: 68.0,
      notes: 'Initial check-in',
    ));
    localCache.addProgressLog(ProgressLogModel(
      id: 'log_a_2',
      userId: 'client_track_a',
      date: DateTime.now().subtract(const Duration(days: 2)),
      weightKg: 70.5,
      notes: 'Gained muscle mass',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachNotifierProvider.overrideWith(() => MockCoachNotifier([clientA, clientB])),
        ],
        child: const MaterialApp(
          home: CoachDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify Progress Tracking widget is rendered
    expect(find.text('Progress Tracking'), findsOneWidget);
    expect(find.textContaining('Current: 70.5 kg'), findsOneWidget);
    expect(find.textContaining('Change: +2.5 kg'), findsOneWidget);
    expect(find.text('Member-Logged'), findsOneWidget);
    expect(find.text('+ Log Weigh-in'), findsNothing);

    // 2. Tap 'Trend' to expand the full LineChart
    await tester.tap(find.text('Trend'));
    await tester.pumpAndSettle();

    // Verify expanded view elements (Read-only for coach)
    expect(find.text('Client Progress Tracking'), findsOneWidget);
    expect(find.text('Weight Trend (kg)'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('70.5 kg'), findsWidgets);
    expect(find.text('+2.5 kg'), findsOneWidget);
    expect(find.text('View Only'), findsOneWidget);
    expect(find.text('Recorded by Member'), findsOneWidget);
    expect(find.text('Log Check-in'), findsNothing);
    expect(find.text('Add Entry'), findsNothing);

    // 3. Switch active client via dropdown in progress tracking card
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Carla Gomez').last);
    await tester.pumpAndSettle();

    // Carla's tracking info is now displayed
    expect(find.textContaining('Carla Gomez'), findsWidgets);
    expect(find.textContaining('from 64.0 kg'), findsOneWidget);
  });

  testWidgets('Tapping "Track" on client card switches tracking to that member and renders their progress', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final localCache = LocalCacheService();

    final clientA = UserModel(
      id: 'client_track_1',
      name: 'Sude Demirtas',
      email: 'sude1@test.com',
      role: UserRole.member,
      fitnessGoal: 'Muscle Gain',
      heightCm: 172,
      weightKg: 68.0,
      experienceLevel: 'Beginner',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    final clientB = UserModel(
      id: 'client_track_2',
      name: 'Carla Gomez',
      email: 'carla2@test.com',
      role: UserRole.member,
      fitnessGoal: 'Fat Loss',
      heightCm: 162,
      weightKg: 64.0,
      experienceLevel: 'Intermediate',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );

    // Seed Carla's progress logs
    localCache.addProgressLog(ProgressLogModel(
      id: 'log_carla_1',
      userId: 'client_track_2',
      date: DateTime.now().subtract(const Duration(days: 10)),
      weightKg: 64.0,
      notes: 'Starting check-in',
    ));
    localCache.addProgressLog(ProgressLogModel(
      id: 'log_carla_2',
      userId: 'client_track_2',
      date: DateTime.now().subtract(const Duration(days: 3)),
      weightKg: 61.5,
      notes: 'Lost 2.5kg body fat',
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachNotifierProvider.overrideWith(() => MockCoachNotifier([clientA, clientB])),
        ],
        child: const MaterialApp(
          home: CoachDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find the Track button for Carla Gomez
    final trackButtons = find.widgetWithText(TextButton, 'Track');
    expect(trackButtons, findsWidgets);

    // Tap Track on Carla's card (the second Track button)
    await tester.tap(trackButtons.at(1));
    await tester.pumpAndSettle();

    // Verify Progress Tracking expanded and Carla's metrics are shown
    expect(find.text('Client Progress Tracking'), findsOneWidget);
    expect(find.textContaining('Recorded biometric progression for Carla Gomez'), findsOneWidget);
    expect(find.text('61.5 kg'), findsWidgets);
    expect(find.text('-2.5 kg'), findsOneWidget);
    expect(find.text('from 64.0 kg'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);

    // Scroll down to verify the TRACKING badge on Carla's card in the client roster
    await tester.scrollUntilVisible(
      find.text('TRACKING'),
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TRACKING'), findsOneWidget);
  });

  testWidgets('Coach Dashboard tracks accomplished workouts for member on a coach plan', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final localCache = LocalCacheService();

    final vipMember = UserModel(
      id: 'member_vip_123',
      name: 'Michael Jordan',
      email: 'mj@test.com',
      role: UserRole.member,
      fitnessGoal: 'Weight Loss',
      heightCm: 198,
      weightKg: 95.0,
      experienceLevel: 'Intermediate',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    );

    // Save VIP Membership (Plan with Coach)
    final vipMembership = MembershipModel(
      id: 'mem_vip_123',
      userId: vipMember.id,
      planName: 'VIP All-Access Pass',
      price: 2800.0,
      startDate: DateTime.now().subtract(const Duration(days: 5)),
      endDate: DateTime.now().add(const Duration(days: 25)),
      status: MembershipStatus.active,
    );
    localCache.saveMembership(vipMembership);

    // Create Workout Routine with 4 exercises, 1 accomplished (Barbell Bench Press)
    final workout = WorkoutPlanModel(
      id: 'workout_mj_123',
      userId: vipMember.id,
      splitTitle: 'Upper-Lower Lean Definition (95kg)',
      confidenceScore: 0.92,
      source: 'ml_model_v1',
      summary: 'Targeted for weight loss with free weights and compound lifts.',
      exercises: [
        const ExerciseModel(
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          sets: '4',
          reps: '8-10',
          restSec: 75,
          equipment: 'Barbell & Bench',
          isCompleted: true, // Accomplished!
          dayTag: 'Day 1: Upper',
        ),
        const ExerciseModel(
          name: 'Single-Arm Dumbbell Row',
          muscleGroup: 'Upper Back',
          sets: '4',
          reps: '10-12',
          restSec: 60,
          equipment: 'Dumbbell & Bench',
          isCompleted: false, // Pending
          dayTag: 'Day 1: Upper',
        ),
        const ExerciseModel(
          name: 'Incline Dumbbell Press',
          muscleGroup: 'Upper Chest',
          sets: '3',
          reps: '10-12',
          restSec: 60,
          equipment: 'Dumbbells',
          isCompleted: false, // Pending
          dayTag: 'Day 1: Upper',
        ),
        const ExerciseModel(
          name: 'Cable Face Pull',
          muscleGroup: 'Rear Delts',
          sets: '3',
          reps: '15',
          restSec: 45,
          equipment: 'Cable Machine',
          isCompleted: false, // Pending
          dayTag: 'Day 1: Upper',
        ),
      ],
      generatedAt: DateTime.now(),
    );
    localCache.saveWorkoutPlan(workout);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          coachNotifierProvider.overrideWith(() => MockCoachNotifier([vipMember], {vipMember.id: workout})),
        ],
        child: const MaterialApp(
          home: CoachDashboardScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // In collapsed view, verify the Today: 1/4 done pill is shown
    expect(find.text('Today: 1/4 done'), findsOneWidget);

    // Expand the progress tracking section
    await tester.tap(find.text('Trend'));
    await tester.pumpAndSettle();

    // Verify Today's Accomplished Workout Section
    expect(find.text("Today's Accomplished Workout"), findsOneWidget);
    expect(find.text('VIP All-Access Pass'), findsWidgets);
    expect(find.text('Upper-Lower Lean Definition (95kg)'), findsWidgets);
    expect(find.text('Session Progress: 1 of 4 exercises completed today'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    // Verify Barbell Bench Press is under Accomplished Today with ACCOMPLISHED badge
    expect(find.text('Accomplished Today:'), findsOneWidget);
    expect(find.text('Barbell Bench Press'), findsOneWidget);
    expect(find.text('ACCOMPLISHED'), findsOneWidget);

    // Verify remaining exercises are under Remaining for Session
    expect(find.text('Remaining for Session (3):'), findsOneWidget);
    expect(find.text('Single-Arm Dumbbell Row'), findsOneWidget);
    expect(find.text('PENDING'), findsWidgets);
  });
}
