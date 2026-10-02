import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/domain/entities/facility_entity.dart';
import 'package:gym_management_system/domain/entities/workout_plan_entity.dart';
import 'package:gym_management_system/domain/services/exercise_alternative_service.dart';
import 'package:gym_management_system/presentation/admin/providers/facility_provider.dart';
import 'package:gym_management_system/presentation/workout/providers/workout_provider.dart';
import 'package:gym_management_system/presentation/workout/widgets/exercise_card.dart';
import 'package:gym_management_system/presentation/workout/widgets/ai_exercise_alternative_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ExerciseAlternativeService Biomechanical Recommendation Engine', () {
    final service = ExerciseAlternativeService();

    test('recommends valid biomechanical alternatives for Leg Press Machine', () {
      const exercise = ExerciseEntity(
        name: 'Leg Press Machine',
        muscleGroup: 'Quadriceps',
        sets: '4',
        reps: '10-12',
        restSec: 75,
        equipment: 'Leg Press Machine',
      );

      final alternatives = service.getAlternatives(exercise: exercise);

      expect(alternatives.isNotEmpty, isTrue);
      expect(alternatives.any((a) => a.alternativeName.contains('Bulgarian Split Squat')), isTrue);
      expect(alternatives.any((a) => a.alternativeName.contains('Goblet Squat')), isTrue);

      final topChoice = alternatives.first;
      expect(topChoice.matchPercentage, greaterThanOrEqualTo(90));
      expect(topChoice.aiRationale, isNotEmpty);
      expect(topChoice.alternativeEquipment, contains('Dumbbells'));

      final entity = topChoice.toExerciseEntity(dayTag: 'Day 1: Legs');
      expect(entity.name, topChoice.alternativeName);
      expect(entity.dayTag, 'Day 1: Legs');
      expect(entity.instructions, contains('AI Alternative'));
    });

    test('recommends valid biomechanical alternatives for Lat Pull Down Machine', () {
      const exercise = ExerciseEntity(
        name: 'Lat Pull Down Machine',
        muscleGroup: 'Lats & Upper Back',
        sets: '3',
        reps: '12',
        restSec: 60,
        equipment: 'Lat Pull Down Machine',
      );

      final alternatives = service.getAlternatives(exercise: exercise);

      expect(alternatives.isNotEmpty, isTrue);
      expect(alternatives.any((a) => a.alternativeName.contains('Pull-Ups')), isTrue);
      expect(alternatives.first.matchPercentage, greaterThanOrEqualTo(95));
      expect(alternatives.first.aiRationale, contains('vertical'));
    });

    test('recommends valid biomechanical alternatives for Peck Deck Fly Machine', () {
      const exercise = ExerciseEntity(
        name: 'Peck Deck Fly Machine',
        muscleGroup: 'Pectorals',
        sets: '3',
        reps: '12',
        restSec: 60,
        equipment: 'Peck Deck Fly Machine',
      );

      final alternatives = service.getAlternatives(exercise: exercise);

      expect(alternatives.isNotEmpty, isTrue);
      expect(alternatives.any((a) => a.alternativeName.contains('Dumbbell Chest Flyes')), isTrue);
    });

    test('recommends valid alternatives for Commercial Treadmill when occupied', () {
      const exercise = ExerciseEntity(
        name: 'Incline Treadmill Sprints',
        muscleGroup: 'Cardiovascular',
        sets: '5',
        reps: '15 mins',
        restSec: 45,
        equipment: 'Commercial Treadmill',
      );

      final alternatives = service.getAlternatives(exercise: exercise);

      expect(alternatives.isNotEmpty, isTrue);
      expect(alternatives.any((a) => a.alternativeName.contains('AirBike') || a.alternativeName.contains('Rower')), isTrue);
    });

    test('detects when equipment is occupied or in-use', () {
      const exercise = ExerciseEntity(
        name: 'Heavy Leg Press',
        muscleGroup: 'Quadriceps',
        sets: '4',
        reps: '10',
        restSec: 90,
        equipment: 'Leg Press Machine',
      );

      final equipmentList = [
        EquipmentEntity(
          id: 'eq_leg_press_01',
          facilityId: 'fac_free_weights_01',
          facilityName: 'Free Weights & Powerlifting Area',
          name: 'Leg Press Machine',
          category: 'Strength',
          serialNumber: 'VF-FW-007',
          status: 'occupied',
          lastMaintained: DateTime.now(),
          nextMaintenanceDate: DateTime.now().add(const Duration(days: 30)),
        ),
      ];

      final isOccupied = service.isEquipmentOccupied(exercise, equipment: equipmentList);
      final notice = service.getOccupancyNotice(exercise, equipment: equipmentList);

      expect(isOccupied, isTrue);
      expect(notice, contains('occupied'));

      final alternatives = service.getAlternatives(exercise: exercise, equipment: equipmentList);
      expect(alternatives.first.isOccupied, isTrue);
      expect(alternatives.first.occupiedReason, contains('occupied'));
    });

    test('detects when facility zone is at 100% full capacity', () {
      const exercise = ExerciseEntity(
        name: 'Heavy Leg Press',
        muscleGroup: 'Quadriceps',
        sets: '4',
        reps: '10',
        restSec: 90,
        equipment: 'Leg Press Machine',
      );

      final equipmentList = [
        EquipmentEntity(
          id: 'eq_leg_press_01',
          facilityId: 'fac_free_weights_01',
          facilityName: 'Free Weights & Powerlifting Area',
          name: 'Leg Press Machine',
          category: 'Strength',
          serialNumber: 'VF-FW-007',
          status: 'operational',
          lastMaintained: DateTime.now(),
          nextMaintenanceDate: DateTime.now().add(const Duration(days: 30)),
        ),
      ];

      final facilitiesList = [
        const FacilityEntity(
          id: 'fac_free_weights_01',
          name: 'Free Weights & Powerlifting Area',
          description: 'Power racks and leg press',
          capacity: 20,
          currentOccupancy: 20, // 100% capacity!
        ),
      ];

      expect(facilitiesList.first.isFullyOccupied, isTrue);
      final isOccupied = service.isEquipmentOccupied(exercise, equipment: equipmentList, facilities: facilitiesList);
      final notice = service.getOccupancyNotice(exercise, equipment: equipmentList, facilities: facilitiesList);

      expect(isOccupied, isTrue);
      expect(notice, contains('capacity'));
    });
  });

  group('WorkoutNotifier Exercise Swapping', () {
    test('successfully swaps occupied exercise with AI recommended alternative', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final originalPlan = WorkoutPlanEntity(
        id: 'plan_test_01',
        userId: 'user_test_01',
        splitTitle: 'Push-Pull-Legs',
        confidenceScore: 0.95,
        source: 'test_engine',
        summary: 'Test workout plan',
        generatedAt: DateTime(2026, 10, 1),
        exercises: [
          ExerciseEntity(
            name: 'Leg Press Machine',
            muscleGroup: 'Quadriceps',
            sets: '4',
            reps: '10-12',
            restSec: 75,
            equipment: 'Leg Press Machine',
            dayTag: 'Day 3: Legs',
          ),
          ExerciseEntity(
            name: 'Barbell Flat Bench Press',
            muscleGroup: 'Chest',
            sets: '4',
            reps: '8-10',
            restSec: 90,
            equipment: 'Barbell & Bench',
            dayTag: 'Day 1: Push',
          ),
        ],
      );

      final notifier = container.read(workoutNotifierProvider.notifier);
      container.read(workoutNotifierProvider); // initialize
      notifier.state = WorkoutState(activePlan: originalPlan);

      const altExercise = ExerciseEntity(
        name: 'Dumbbell Bulgarian Split Squat',
        muscleGroup: 'Quadriceps & Glutes',
        sets: '4',
        reps: '10-12 / leg',
        restSec: 75,
        equipment: 'Dumbbells & Flat Bench',
        dayTag: 'Day 3: Legs',
      );

      notifier.swapExercise(originalPlan.exercises.first, altExercise);

      final updatedPlan = container.read(workoutNotifierProvider).activePlan;
      expect(updatedPlan, isNotNull);
      expect(updatedPlan!.exercises.first.name, 'Dumbbell Bulgarian Split Squat');
      expect(updatedPlan.exercises.first.equipment, 'Dumbbells & Flat Bench');
      expect(updatedPlan.exercises.first.dayTag, 'Day 3: Legs');
      // Second exercise should remain unchanged
      expect(updatedPlan.exercises[1].name, 'Barbell Flat Bench Press');
    });
  });

  group('Widget UI Integration: ExerciseCard and AI Modal', () {
    testWidgets('displays machine busy warning and opens AI modal on tap', (tester) async {
      const exercise = ExerciseEntity(
        name: 'Leg Press Machine',
        muscleGroup: 'Quadriceps',
        sets: '4',
        reps: '10-12',
        restSec: 75,
        equipment: 'Leg Press Machine',
        dayTag: 'Day 3: Legs',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExerciseCard(
                exercise: exercise,
                onToggle: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify exercise card rendered
      expect(find.text('Leg Press Machine'), findsWidgets);
      expect(find.text('AI Alternative'), findsOneWidget);

      // Tap on AI Alternative button to open bottom sheet modal
      await tester.tap(find.text('AI Alternative'));
      await tester.pumpAndSettle();

      // Verify AI Alternative Modal opened
      expect(find.text('AI Exercise Alternative'), findsOneWidget);
      expect(find.textContaining('Smart substitution for Leg Press Machine'), findsOneWidget);
      expect(find.text('Dumbbell Bulgarian Split Squat'), findsOneWidget);
      expect(find.text('Swap to this Exercise in Workout'), findsWidgets);
    });
  });
}
