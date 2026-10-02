import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../data/models/workout_plan_model.dart';
import '../../../data/models/meal_plan_model.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../domain/repositories/coach_repository.dart';
import '../../../data/repositories/coach_repository_impl.dart';
import '../../../data/repositories/workout_repository_impl.dart';
import '../../../data/repositories/meal_repository_impl.dart';

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  return CoachRepositoryImpl();
});

class CoachState {
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> clients;
  final Map<String, WorkoutPlanModel?> clientWorkouts;
  final Map<String, MealPlanModel?> clientMeals;
  final List<TrainingSessionModel> sessions;

  const CoachState({
    this.isLoading = false,
    this.errorMessage,
    this.clients = const [],
    this.clientWorkouts = const {},
    this.clientMeals = const {},
    this.sessions = const [],
  });

  CoachState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<UserModel>? clients,
    Map<String, WorkoutPlanModel?>? clientWorkouts,
    Map<String, MealPlanModel?>? clientMeals,
    List<TrainingSessionModel>? sessions,
  }) {
    return CoachState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      clients: clients ?? this.clients,
      clientWorkouts: clientWorkouts ?? this.clientWorkouts,
      clientMeals: clientMeals ?? this.clientMeals,
      sessions: sessions ?? this.sessions,
    );
  }
}

class CoachNotifier extends Notifier<CoachState> {
  late CoachRepository _repo;
  bool _isFetching = false;

  @override
  CoachState build() {
    _repo = ref.read(coachRepositoryProvider);
    final curUser = LocalCacheService().getCurrentUser();
    if (curUser == null || curUser.role != UserRole.coach) {
      return const CoachState(
        isLoading: false,
        clients: [],
        clientWorkouts: {},
        clientMeals: {},
        sessions: [],
      );
    }

    final coachId = curUser.id;
    final cachedClients = _repo.getCachedAssignedClients(coachId);
    final cachedWorkouts = _repo.getCachedWorkoutPlans(coachId);
    final cachedMeals = _repo.getCachedMealPlans(coachId);

    Future.microtask(() => loadDashboard(coachId));

    return CoachState(
      isLoading: false,
      clients: cachedClients,
      clientWorkouts: cachedWorkouts,
      clientMeals: cachedMeals,
    );
  }

  Future<void> loadDashboard([String? coachId]) async {
    if (_isFetching) return;
    _isFetching = true;

    final curUser = LocalCacheService().getCurrentUser();
    final effectiveCoachId = coachId ?? (curUser?.role == UserRole.coach ? curUser?.id : null);

    if (effectiveCoachId == null) {
      state = state.copyWith(
        isLoading: false,
        clients: const [],
        clientWorkouts: const {},
        clientMeals: const {},
        sessions: const [],
      );
      _isFetching = false;
      return;
    }

    try {
      final results = await Future.wait([
        _repo.getAssignedClients(effectiveCoachId),
        _repo.getAllClientWorkoutPlans(effectiveCoachId),
        _repo.getAllClientMealPlans(effectiveCoachId),
        _repo.getCoachSessions(effectiveCoachId),
      ]);

      final clients = results[0] as List<UserModel>;
      final workouts = results[1] as Map<String, WorkoutPlanModel?>;
      final meals = results[2] as Map<String, MealPlanModel?>;
      final sessions = results[3] as List<TrainingSessionModel>;

      state = state.copyWith(
        isLoading: false,
        clients: clients,
        clientWorkouts: workouts,
        clientMeals: meals,
        sessions: sessions,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isFetching = false;
    }
  }

  void reset() {
    state = const CoachState();
  }

  Future<bool> approveWorkout(String clientUserId, [String? notes]) async {
    // Optimistic UI update
    final currentPlan = state.clientWorkouts[clientUserId];
    if (currentPlan != null) {
      final updated = currentPlan.copyWith(isCoachApproved: true, coachNotes: notes);
      final newWorkouts = Map<String, WorkoutPlanModel?>.from(state.clientWorkouts);
      newWorkouts[clientUserId] = updated;
      state = state.copyWith(clientWorkouts: newWorkouts);
    }

    try {
      await _repo.approveWorkoutPlan(clientUserId, notes: notes);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> approveMeal(String clientUserId, [String? notes]) async {
    // Optimistic UI update
    final currentMeal = state.clientMeals[clientUserId];
    if (currentMeal != null) {
      final updated = currentMeal.copyWith(isCoachApproved: true, coachNotes: notes);
      final newMeals = Map<String, MealPlanModel?>.from(state.clientMeals);
      newMeals[clientUserId] = updated;
      state = state.copyWith(clientMeals: newMeals);
    }

    try {
      await _repo.approveMealPlan(clientUserId, notes: notes);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> scheduleSession(TrainingSessionModel session) async {
    final h = session.dateTime.hour;
    if (h < 8 || h >= 23) {
      state = state.copyWith(errorMessage: 'Cannot schedule session outside gym operating hours (8:00 AM – 11:00 PM).');
      return false;
    }

    try {
      await _repo.scheduleSession(session);
      final newSessions = [session, ...state.sessions];
      state = state.copyWith(sessions: newSessions, errorMessage: null);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> cancelSession(String sessionId) async {
    try {
      await _repo.cancelSession(sessionId);
      final updated = state.sessions.where((s) => s.id != sessionId).toList();
      state = state.copyWith(sessions: updated);
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return false;
    }
  }

  Future<WorkoutPlanModel?> generateWorkoutForClient(UserModel client) async {
    state = state.copyWith(isLoading: true);
    try {
      final repo = WorkoutRepositoryImpl();
      final plan = await repo.generateWorkoutRecommendation(client);
      final model = WorkoutPlanModel(
        id: plan.id,
        userId: plan.userId,
        splitTitle: plan.splitTitle,
        confidenceScore: plan.confidenceScore,
        source: plan.source,
        summary: plan.summary,
        exercises: plan.exercises,
        generatedAt: plan.generatedAt,
        isCoachApproved: true,
        coachNotes: 'Prescribed and approved directly by Coach.',
      );
      LocalCacheService().saveWorkoutPlan(model);
      final newWorkouts = Map<String, WorkoutPlanModel?>.from(state.clientWorkouts);
      newWorkouts[client.id] = model;
      state = state.copyWith(isLoading: false, clientWorkouts: newWorkouts);
      return model;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<MealPlanModel?> generateMealForClient(UserModel client) async {
    state = state.copyWith(isLoading: true);
    try {
      final bmr = BmiCalculator.calculateBmr(
        weightKg: client.weightKg,
        heightCm: client.heightCm,
        age: client.age,
        gender: client.gender,
      );
      final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: client.activityLevel);
      final tCal = BmiCalculator.calculateTargetCalories(
        tdee: tdee,
        fitnessGoal: client.fitnessGoal,
        bmi: client.bmi,
      );
      final macros = BmiCalculator.calculateTargetMacros(targetCalories: tCal, fitnessGoal: client.fitnessGoal);

      final repo = MealRepositoryImpl();
      final plan = await repo.generateMealPlanOptimization(
        user: client,
        targetCalories: tCal,
        targetProtein: macros.protein,
        targetCarbs: macros.carbs,
        targetFat: macros.fat,
      );
      final model = plan is MealPlanModel
          ? plan.copyWith(
              isCoachApproved: true,
              coachNotes: 'Prescribed and approved directly by Coach.',
            )
          : MealPlanModel(
              id: plan.id,
              userId: plan.userId,
              source: plan.source,
              totalCalories: plan.totalCalories,
              targetCalories: plan.targetCalories,
              totalProtein: plan.totalProtein,
              targetProtein: plan.targetProtein,
              totalCarbs: plan.totalCarbs,
              targetCarbs: plan.targetCarbs,
              totalFat: plan.totalFat,
              targetFat: plan.targetFat,
              totalCost: plan.totalCost,
              budgetLimit: plan.budgetLimit,
              isFeasible: plan.isFeasible,
              solverMessage: plan.solverMessage,
              meals: plan.meals,
              generatedAt: plan.generatedAt,
              isCoachApproved: true,
              coachNotes: 'Prescribed and approved directly by Coach.',
            );
      LocalCacheService().saveMealPlan(model);
      final newMeals = Map<String, MealPlanModel?>.from(state.clientMeals);
      newMeals[client.id] = model;
      state = state.copyWith(isLoading: false, clientMeals: newMeals);
      return model;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final coachNotifierProvider = NotifierProvider<CoachNotifier, CoachState>(CoachNotifier.new);
