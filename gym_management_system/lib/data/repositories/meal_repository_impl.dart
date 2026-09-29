import '../../config/env.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/meal_plan_entity.dart';
import '../../domain/repositories/meal_repository.dart';
import '../models/meal_plan_model.dart';
import '../datasources/remote/recommendation_api_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class MealRepositoryImpl implements MealRepository {
  final RecommendationApiService _apiService;
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  MealRepositoryImpl({
    RecommendationApiService? apiService,
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _apiService = apiService ?? RecommendationApiService(),
        _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  @override
  Future<MealPlanEntity> generateMealPlanOptimization({
    required UserEntity user,
    required double targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    List<String> dietaryRestrictions = const [],
    double? budgetLimit,
  }) async {
    final model = await _apiService.getMealPlanOptimization(
      user: user,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      dietaryRestrictions: dietaryRestrictions,
      budgetLimit: budgetLimit,
    );
    final toSave = (model.userId.isEmpty || model.id.isEmpty)
        ? model.copyWith(
            id: model.id.isNotEmpty ? model.id : 'meal_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
            userId: user.id,
          )
        : model;
    await saveMealPlan(toSave);
    return toSave;
  }

  @override
  Future<MealPlanEntity?> getActiveMealPlan(String userId) async {
    if (Env.useFirebase) {
      try {
        final plan = await _firestore.getLatestMealPlan(userId);
        if (plan != null) {
          _localCache.saveMealPlan(plan);
          return plan;
        }
      } catch (_) {}
    }
    return _localCache.getMealPlan(userId);
  }

  @override
  Future<void> saveMealPlan(MealPlanEntity plan) async {
    final planId = plan.id.isNotEmpty ? plan.id : 'meal_${plan.userId}_${DateTime.now().millisecondsSinceEpoch}';
    final model = plan is MealPlanModel && plan.id.isNotEmpty
        ? plan
        : MealPlanModel(
            id: planId,
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
            isCoachApproved: plan.isCoachApproved,
            coachNotes: plan.coachNotes,
          );

    if (Env.useFirebase) {
      try {
        await _firestore.saveMealPlan(model);
      } catch (_) {}
    }
    _localCache.saveMealPlan(model);
  }
}
