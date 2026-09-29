import 'package:flutter_test/flutter_test.dart';
import 'package:gym_management_system/domain/entities/user_entity.dart';
import 'package:gym_management_system/data/models/user_model.dart';
import 'package:gym_management_system/data/datasources/local/local_cache_service.dart';
import 'package:gym_management_system/data/repositories/admin_repository_impl.dart';
import 'package:gym_management_system/data/repositories/coach_repository_impl.dart';
import 'package:gym_management_system/data/repositories/workout_repository_impl.dart';
import 'package:gym_management_system/data/repositories/meal_repository_impl.dart';

void main() {
  group('Full Member, Admin, and Coach Feature Flow Tests', () {
    late LocalCacheService localCache;
    late AdminRepositoryImpl adminRepo;
    late CoachRepositoryImpl coachRepo;
    late WorkoutRepositoryImpl workoutRepo;
    late MealRepositoryImpl mealRepo;

    late UserModel testMember;

    setUp(() {
      localCache = LocalCacheService();
      adminRepo = AdminRepositoryImpl(localCache: localCache);
      coachRepo = CoachRepositoryImpl(localCache: localCache);
      workoutRepo = WorkoutRepositoryImpl();
      mealRepo = MealRepositoryImpl();

      testMember = UserModel(
        id: 'member_test_99',
        name: 'Carlos Yulo',
        email: 'carlos@gym.com',
        role: UserRole.member,
        age: 25,
        heightCm: 165.0,
        weightKg: 62.0,
        gender: 'Male',
        fitnessGoal: 'Muscle Gain',
        activityLevel: 'Very Active',
        experienceLevel: 'Advanced',
        createdAt: DateTime.now(),
      );
      localCache.saveUser(testMember);
    });

    test('Member flow: Generates workout plan list, meal plan, progress, and membership expiry', () async {
      // 1. Generate workout routine
      final workoutPlan = await workoutRepo.generateWorkoutRecommendation(testMember);
      expect(workoutPlan.exercises, isNotEmpty);
      expect(workoutPlan.splitTitle, isNotEmpty);
      expect(workoutPlan.exercises.first.name, isNotEmpty);
      localCache.saveWorkoutPlan(workoutPlan as dynamic);

      // 2. Generate meal plan
      final mealPlan = await mealRepo.generateMealPlanOptimization(
        user: testMember,
        targetCalories: 2450.0,
      );
      expect(mealPlan.meals, isNotEmpty);
      expect(mealPlan.totalCalories, greaterThan(1000));
      localCache.saveMealPlan(mealPlan as dynamic);

      // 3. Record payment and check membership expiration date
      await adminRepo.recordPayment(
        userId: testMember.id,
        planName: 'VIP All-Access Pass',
        amount: 2800.0,
        durationDays: 30,
      );
      final mem = localCache.getMembership(testMember.id);
      expect(mem, isNotNull);
      expect(mem!.remainingDays, inInclusiveRange(29, 31));
      expect(mem.endDate.isAfter(DateTime.now()), isTrue);

      // 4. Progress logs
      final logs = localCache.getProgressLogs(testMember.id);
      expect(logs, isA<List>());
    });

    test('Admin flow: Sends expiration notice to member, member receives notice', () async {
      final targetUserId = testMember.id;
      const noticeTitle = 'Gym Membership Expiration Notice';
      const noticeMsg = 'Your membership expires in 3 days. Please visit the desk to renew!';

      await adminRepo.sendExpirationNotice(
        userId: targetUserId,
        title: noticeTitle,
        message: noticeMsg,
      );

      final notifs = localCache.getNotifications(targetUserId);
      expect(notifs, isNotEmpty);
      expect(notifs.first.title, equals(noticeTitle));
      expect(notifs.first.message, equals(noticeMsg));

      // Member can dismiss notice
      localCache.dismissNotification(notifs.first.id);
      expect(localCache.getNotifications(targetUserId), isEmpty);
    });

    test('Coach flow: Inspects member, approves workout & meal plan, and schedules training session', () async {
      final targetUserId = testMember.id;
      final member = localCache.getUserById(targetUserId)!;

      final wPlan = await workoutRepo.generateWorkoutRecommendation(member);
      localCache.saveWorkoutPlan(wPlan as dynamic);

      final mPlan = await mealRepo.generateMealPlanOptimization(
        user: member,
        targetCalories: 2450.0,
      );
      localCache.saveMealPlan(mPlan as dynamic);

      // 1. Client routine exists
      final workout = await coachRepo.getClientWorkoutPlan(targetUserId);
      expect(workout, isNotNull);

      // 2. Coach approves workout
      await coachRepo.approveWorkoutPlan(targetUserId, notes: 'Great form!');
      final updatedWorkout = await coachRepo.getClientWorkoutPlan(targetUserId);
      expect(updatedWorkout?.isCoachApproved, isTrue);
      expect(updatedWorkout?.coachNotes, contains('Great form!'));

      // 3. Coach approves meal plan
      await coachRepo.approveMealPlan(targetUserId, notes: 'Good protein target.');
      final updatedMeal = await coachRepo.getClientMealPlan(targetUserId);
      expect(updatedMeal?.isCoachApproved, isTrue);

      // 4. Coach schedules training session
      final newSession = TrainingSessionModel(
        id: 'sess_101',
        coachId: 'coach_demo_01',
        coachName: 'Coach Marcus',
        memberId: targetUserId,
        memberName: member.name,
        dateTime: DateTime.now().add(const Duration(days: 2)),
        focus: 'Hypertrophy & Form Check',
        status: 'Confirmed',
      );
      await coachRepo.scheduleSession(newSession);

      final sessions = await coachRepo.getCoachSessions('coach_demo_01');
      expect(sessions.any((s) => s.id == 'sess_101'), isTrue);
    });
  });
}
