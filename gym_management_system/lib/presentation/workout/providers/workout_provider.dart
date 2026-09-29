import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/workout_plan_entity.dart';
import '../../../domain/repositories/workout_repository.dart';
import '../../../data/repositories/workout_repository_impl.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepositoryImpl();
});

class WorkoutState {
  final WorkoutPlanEntity? activePlan;
  final bool isLoading;
  final String? errorMessage;

  const WorkoutState({
    this.activePlan,
    this.isLoading = false,
    this.errorMessage,
  });

  WorkoutState copyWith({
    WorkoutPlanEntity? activePlan,
    bool clearPlan = false,
    bool? isLoading,
    String? errorMessage,
  }) {
    return WorkoutState(
      activePlan: clearPlan ? null : (activePlan ?? this.activePlan),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class WorkoutNotifier extends Notifier<WorkoutState> {
  late WorkoutRepository _repo;

  @override
  WorkoutState build() {
    _repo = ref.read(workoutRepositoryProvider);
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    if (user != null) {
      final cachedPlan = LocalCacheService().getWorkoutPlan(user.id);
      if (cachedPlan != null) {
        return WorkoutState(activePlan: cachedPlan);
      }
    }
    return const WorkoutState();
  }

  void reset() {
    state = const WorkoutState();
  }

  Future<WorkoutPlanEntity?> loadActivePlan(String userId) async {
    // If not loaded in state, check local cache first for instant synchronous UI display
    if (state.activePlan == null) {
      final cached = LocalCacheService().getWorkoutPlan(userId);
      if (cached != null) {
        state = state.copyWith(activePlan: cached);
      }
    }

    state = state.copyWith(isLoading: state.activePlan == null, errorMessage: null);
    try {
      final plan = await _repo.getActiveWorkoutPlan(userId);
      if (plan != null) {
        // Merge completed exercise statuses if current state already has user completions
        final currentPlan = state.activePlan;
        final mergedExercises = plan.exercises.map((incomingEx) {
          if (currentPlan != null) {
            final matching = currentPlan.exercises.where((e) =>
                e.name == incomingEx.name &&
                (incomingEx.dayTag.isEmpty || e.dayTag == incomingEx.dayTag)).firstOrNull;
            if (matching != null && matching.isCompleted) {
              return incomingEx.copyWith(isCompleted: true);
            }
          }
          return incomingEx;
        }).toList();

        final mergedPlan = plan.copyWith(exercises: mergedExercises);
        state = state.copyWith(
          activePlan: mergedPlan,
          isLoading: false,
        );
        _repo.saveWorkoutPlan(mergedPlan);
        return mergedPlan;
      } else if (state.activePlan != null) {
        state = state.copyWith(isLoading: false);
        return state.activePlan;
      } else {
        state = state.copyWith(clearPlan: true, isLoading: false);
        return null;
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return state.activePlan;
    }
  }

  Future<void> generatePlan(UserEntity user) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final plan = await _repo.generateWorkoutRecommendation(user);
      state = state.copyWith(activePlan: plan, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to generate recommendation: ${e.toString()}',
      );
    }
  }

  void toggleExerciseCompletion(dynamic target) {
    final plan = state.activePlan;
    if (plan == null) return;
    int index = -1;
    if (target is int) {
      index = target;
    } else if (target is ExerciseEntity) {
      index = plan.exercises.indexWhere(
        (e) => e.name == target.name && (target.dayTag.isEmpty || e.dayTag == target.dayTag),
      );
    }
    if (index < 0 || index >= plan.exercises.length) return;
    final updatedList = List<ExerciseEntity>.from(plan.exercises);
    final current = updatedList[index];
    updatedList[index] = current.copyWith(isCompleted: !current.isCompleted);

    final updatedPlan = WorkoutPlanEntity(
      id: plan.id,
      userId: plan.userId,
      splitTitle: plan.splitTitle,
      confidenceScore: plan.confidenceScore,
      source: plan.source,
      summary: plan.summary,
      exercises: updatedList,
      generatedAt: plan.generatedAt,
      isCoachApproved: plan.isCoachApproved,
      coachNotes: plan.coachNotes,
    );

    state = state.copyWith(activePlan: updatedPlan);
    _repo.saveWorkoutPlan(updatedPlan);
  }
}

final workoutNotifierProvider = NotifierProvider<WorkoutNotifier, WorkoutState>(WorkoutNotifier.new);
