import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/datasources/remote/recommendation_api_service.dart';
import 'package:gym_management_system/data/models/membership_model.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/data/models/workout_plan_model.dart';
import 'package:gym_management_system/domain/entities/membership_entity.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/domain/entities/workout_plan_entity.dart';
import 'package:gym_management_system/core/utils/bmi_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gym_management_system/data/repositories/workout_repository_impl.dart';
import 'package:gym_management_system/data/repositories/meal_repository_impl.dart';

void main() {
  group('Day Split & Coach AI Generation Tests', () {
    late LocalCacheService localCache;
    late RecommendationApiService recommendationService;
    late WorkoutRepositoryImpl workoutRepo;
    late MealRepositoryImpl mealRepo;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      await LocalCacheService.initialize();
      localCache = LocalCacheService();
      recommendationService = RecommendationApiService();
      workoutRepo = WorkoutRepositoryImpl(localCache: localCache, apiService: recommendationService);
      mealRepo = MealRepositoryImpl(localCache: localCache, apiService: recommendationService);
    });

    test('Day Pass walk-in customer receives complete 1-Day Full Body workout with Day 1: Full Body tag', () async {
      final dayPassUser = UserModel(
        id: 'user_day_pass_999',
        name: 'Walk-in John',
        email: 'john_walkin@test.com',
        role: UserRole.member,
        age: 26,
        gender: 'Male',
        heightCm: 175.0,
        weightKg: 72.0,
        fitnessGoal: 'General Fitness',
        activityLevel: 'Lightly Active',
        experienceLevel: 'Beginner',
        createdAt: DateTime.now(),
      );

      // Save Day Pass membership for John
      final dayPassMembership = MembershipModel(
        id: 'mem_day_pass_999',
        userId: dayPassUser.id,
        planName: 'Day Pass',
        price: 150.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 1)),
        status: MembershipStatus.active,
      );
      localCache.saveMembership(dayPassMembership);

      final plan = await workoutRepo.generateWorkoutRecommendation(dayPassUser);

      expect(plan.splitTitle, contains('Day Pass'));
      expect(plan.splitTitle, contains('Full Body'));
      expect(plan.exercises.isNotEmpty, isTrue);
      // Auto-approved autonomous routine for day pass walk-ins without needing coach review
      expect(plan.isCoachApproved, isTrue);
      expect(plan.coachNotes, contains('Autonomous 1-Day Pass Routine'));

      // Verify presence of both Free Weights and Unilateral movements
      expect(plan.exercises.any((e) => e.equipment.contains('Dumbbell')), isTrue);
      expect(plan.exercises.any((e) => e.name.contains('Bulgarian Split Squat')), isTrue);
      expect(plan.exercises.any((e) => e.name.contains('Single-Arm Dumbbell Row')), isTrue);

      // Verify that every single exercise in a day pass has 'Day 1: Full Body'
      for (final ex in plan.exercises) {
        expect(ex.dayTag, 'Day 1: Full Body');
      }
    });

    test('Multi-day member with Muscle Gain receives PPL split with Day 1: Push, Day 2: Pull, Day 3: Legs & Core', () async {
      final monthlyUser = UserModel(
        id: 'user_ppl_monthly_888',
        name: 'Sarah Lifter',
        email: 'sarah_ppl@test.com',
        role: UserRole.member,
        age: 24,
        gender: 'Female',
        heightCm: 165.0,
        weightKg: 58.0,
        fitnessGoal: 'Muscle Gain',
        activityLevel: 'Moderately Active',
        experienceLevel: 'Intermediate',
        createdAt: DateTime.now(),
      );

      // Save Monthly membership
      final monthlyMembership = MembershipModel(
        id: 'mem_monthly_888',
        userId: monthlyUser.id,
        planName: 'Monthly Basic',
        price: 1200.0,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 30)),
        status: MembershipStatus.active,
      );
      localCache.saveMembership(monthlyMembership);

      final plan = await workoutRepo.generateWorkoutRecommendation(monthlyUser);

      expect(plan.splitTitle, contains('Push-Pull-Legs'));
      expect(plan.exercises.isNotEmpty, isTrue);

      // Verify hybrid mix of Barbell, Dumbbell, Unilateral, and Machines
      expect(plan.exercises.any((e) => e.equipment.contains('Barbell')), isTrue);
      expect(plan.exercises.any((e) => e.equipment.contains('Dumbbell')), isTrue);
      expect(plan.exercises.any((e) => e.name.contains('Bulgarian Split Squats')), isTrue);
      expect(plan.exercises.any((e) => e.name.contains('Single-Arm Dumbbell Row')), isTrue);

      final dayTags = plan.exercises.map((e) => e.dayTag).toSet();
      expect(dayTags.contains('Day 1: Push'), isTrue);
      expect(dayTags.contains('Day 2: Pull'), isTrue);
      expect(dayTags.contains('Day 3: Legs & Core'), isTrue);
    });

    test('Multi-day member with Weight Loss receives Upper-Lower split with Day 1: Upper and Day 2: Lower', () async {
      final weightLossUser = UserModel(
        id: 'user_upper_lower_777',
        name: 'Mike Shred',
        email: 'mike_shred@test.com',
        role: UserRole.member,
        age: 30,
        gender: 'Male',
        heightCm: 178.0,
        weightKg: 76.0,
        fitnessGoal: 'Weight Loss',
        activityLevel: 'Moderately Active',
        experienceLevel: 'Intermediate',
        createdAt: DateTime.now(),
      );

      final plan = await workoutRepo.generateWorkoutRecommendation(weightLossUser);

      expect(plan.exercises.isNotEmpty, isTrue);
      final dayTags = plan.exercises.map((e) => e.dayTag).toSet();
      expect(dayTags.contains('Day 1: Upper'), isTrue);
      expect(dayTags.contains('Day 2: Lower'), isTrue);
    });

    test('ExerciseModel and WorkoutPlanModel serialization correctly serializes and deserializes dayTag', () {
      const exercise = ExerciseModel(
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest',
        sets: '4',
        reps: '8-10',
        restSec: 90,
        equipment: 'Barbell & Bench',
        dayTag: 'Day 1: Push',
      );

      final json = exercise.toJson();
      expect(json['day_tag'], 'Day 1: Push');

      final reconstructed = ExerciseModel.fromJson(json);
      expect(reconstructed.dayTag, 'Day 1: Push');
      expect(reconstructed.name, 'Barbell Bench Press');

      final plan = WorkoutPlanModel(
        id: 'test_plan_001',
        userId: 'user_123',
        splitTitle: 'Push-Pull-Legs',
        confidenceScore: 0.95,
        source: 'smart_engine',
        summary: 'PPL routine',
        exercises: [exercise],
        generatedAt: DateTime.now(),
        isCoachApproved: true,
      );

      final planJson = plan.toJson();
      final reconstructedPlan = WorkoutPlanModel.fromJson(planJson);
      expect(reconstructedPlan.exercises.first.dayTag, 'Day 1: Push');
      expect(reconstructedPlan.isCoachApproved, isTrue);
    });

    test('Full coach generation flow generates both workout and meal plan for a blank client', () async {
      final blankClient = UserModel(
        id: 'client_blank_555',
        name: 'Blank Client',
        email: 'blank_client@test.com',
        role: UserRole.member,
        age: 28,
        gender: 'Male',
        heightCm: 172.0,
        weightKg: 70.0,
        fitnessGoal: 'Muscle Gain',
        activityLevel: 'Moderately Active',
        experienceLevel: 'Beginner',
        createdAt: DateTime.now(),
      );

      // Generate Workout
      final workout = await workoutRepo.generateWorkoutRecommendation(blankClient);
      expect(workout.exercises.isNotEmpty, isTrue);
      expect(workout.userId, blankClient.id);

      // Generate Meal Plan
      final bmr = BmiCalculator.calculateBmr(
        weightKg: blankClient.weightKg,
        heightCm: blankClient.heightCm,
        age: blankClient.age,
        gender: blankClient.gender,
      );
      final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: blankClient.activityLevel);
      final tCal = BmiCalculator.calculateTargetCalories(tdee: tdee, fitnessGoal: blankClient.fitnessGoal);
      final macros = BmiCalculator.calculateTargetMacros(targetCalories: tCal, fitnessGoal: blankClient.fitnessGoal);

      final meal = await mealRepo.generateMealPlanOptimization(
        user: blankClient,
        targetCalories: tCal,
        targetProtein: macros.protein,
        targetCarbs: macros.carbs,
        targetFat: macros.fat,
      );

      expect(meal.meals.isNotEmpty, isTrue);
      expect(meal.totalCalories, greaterThan(1500));
      expect(meal.userId, blankClient.id);

      // Verify plans are saved in LocalCacheService
      expect(localCache.getWorkoutPlan(blankClient.id), isNotNull);
      expect(localCache.getMealPlan(blankClient.id), isNotNull);
    });

    test('Exercise completion persists across cache reload and simulated logout (e.g., Barbell Bench Press 1 of 4 completed)', () async {
      await LocalCacheService.initialize();

      final member = UserModel(
        id: 'user_persist_bench_123',
        name: 'Bench Presser',
        email: 'bench@test.com',
        role: UserRole.member,
        age: 25,
        gender: 'Male',
        heightCm: 170.0,
        weightKg: 70.0,
        fitnessGoal: 'Weight Loss',
        activityLevel: 'Lightly Active',
        experienceLevel: 'Beginner',
        createdAt: DateTime.now(),
      );

      // Generate initial workout routine
      final initialPlan = await workoutRepo.generateWorkoutRecommendation(member);
      expect(initialPlan.exercises.isNotEmpty, isTrue);

      // Mark the first exercise (e.g., Barbell Bench Press) as completed (1 of 4 completed)
      final originalEx = initialPlan.exercises.first;
      final updatedExercises = List<ExerciseEntity>.from(initialPlan.exercises);
      updatedExercises[0] = originalEx.copyWith(isCompleted: true);

      final planWithCompletedExercise = WorkoutPlanModel(
        id: initialPlan.id,
        userId: member.id,
        splitTitle: initialPlan.splitTitle,
        confidenceScore: initialPlan.confidenceScore,
        source: initialPlan.source,
        summary: initialPlan.summary,
        exercises: updatedExercises,
        generatedAt: initialPlan.generatedAt,
      );

      await workoutRepo.saveWorkoutPlan(planWithCompletedExercise);

      // Verify it is completed in local cache
      final savedPlan = localCache.getWorkoutPlan(member.id);
      expect(savedPlan, isNotNull);
      expect(savedPlan!.exercises.first.isCompleted, isTrue);
      expect(savedPlan.exercises.where((e) => e.isCompleted).length, 1);

      // Simulate App Restart / User Logout & Re-login: re-initialize LocalCacheService from SharedPreferences
      await LocalCacheService.initialize();

      // Retrieve plan after restart
      final reloadedPlan = await workoutRepo.getActiveWorkoutPlan(member.id);
      expect(reloadedPlan, isNotNull);
      expect(reloadedPlan!.exercises.first.name, equals(originalEx.name));
      expect(reloadedPlan.exercises.first.isCompleted, isTrue);
      expect(reloadedPlan.exercises.where((e) => e.isCompleted).length, 1);
    });
  });
}
