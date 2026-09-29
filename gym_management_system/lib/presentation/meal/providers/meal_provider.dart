import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/meal_plan_entity.dart';
import '../../../domain/repositories/meal_repository.dart';
import '../../../data/repositories/meal_repository_impl.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepositoryImpl();
});

class MealState {
  final MealPlanEntity? activePlan;
  final bool isLoading;
  final String? errorMessage;

  const MealState({
    this.activePlan,
    this.isLoading = false,
    this.errorMessage,
  });

  MealState copyWith({
    MealPlanEntity? activePlan,
    bool clearPlan = false,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MealState(
      activePlan: clearPlan ? null : (activePlan ?? this.activePlan),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class MealNotifier extends Notifier<MealState> {
  late MealRepository _repo;

  @override
  MealState build() {
    _repo = ref.read(mealRepositoryProvider);
    final user = ref.watch(authNotifierProvider.select((s) => s.user));
    if (user != null) {
      final cachedPlan = LocalCacheService().getMealPlan(user.id);
      if (cachedPlan != null) {
        return MealState(activePlan: cachedPlan);
      }
    }
    return const MealState();
  }

  void reset() {
    state = const MealState();
  }

  Future<MealPlanEntity?> loadActivePlan(String userId) async {
    if (state.activePlan == null) {
      final cached = LocalCacheService().getMealPlan(userId);
      if (cached != null) {
        state = state.copyWith(activePlan: cached);
      }
    }

    state = state.copyWith(isLoading: state.activePlan == null, errorMessage: null);
    try {
      final plan = await _repo.getActiveMealPlan(userId);
      if (plan != null) {
        state = state.copyWith(
          activePlan: plan,
          isLoading: false,
        );
        return plan;
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

  Future<void> generateMealPlan({
    required UserEntity user,
    required double targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    List<String> dietaryRestrictions = const [],
    double? budgetLimit,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final plan = await _repo.generateMealPlanOptimization(
        user: user,
        targetCalories: targetCalories,
        targetProtein: targetProtein,
        targetCarbs: targetCarbs,
        targetFat: targetFat,
        dietaryRestrictions: dietaryRestrictions,
        budgetLimit: budgetLimit,
      );
      state = state.copyWith(activePlan: plan, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to optimize meal plan: ${e.toString()}',
      );
    }
  }
}

final mealNotifierProvider = NotifierProvider<MealNotifier, MealState>(MealNotifier.new);
