import '../../config/env.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../../domain/repositories/workout_repository.dart';
import '../models/workout_plan_model.dart';
import '../datasources/remote/recommendation_api_service.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  final RecommendationApiService _apiService;
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  WorkoutRepositoryImpl({
    RecommendationApiService? apiService,
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _apiService = apiService ?? RecommendationApiService(),
        _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  @override
  Future<WorkoutPlanEntity> generateWorkoutRecommendation(UserEntity user) async {
    final model = await _apiService.getWorkoutRecommendation(user);
    final toSave = (model.userId.isEmpty || model.id.isEmpty)
        ? model.copyWith(
            id: model.id.isNotEmpty ? model.id : 'workout_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
            userId: user.id,
          )
        : model;
    await saveWorkoutPlan(toSave);
    return toSave;
  }

  @override
  Future<WorkoutPlanEntity?> getActiveWorkoutPlan(String userId) async {
    if (Env.useFirebase) {
      try {
        final plan = await _firestore.getLatestWorkoutPlan(userId);
        if (plan != null) {
          _localCache.saveWorkoutPlan(plan);
          return plan;
        }
      } catch (_) {}
    }
    return _localCache.getWorkoutPlan(userId);
  }

  @override
  Future<void> saveWorkoutPlan(WorkoutPlanEntity plan) async {
    final planId = plan.id.isNotEmpty ? plan.id : 'workout_${plan.userId}_${DateTime.now().millisecondsSinceEpoch}';
    final model = plan is WorkoutPlanModel && plan.id.isNotEmpty
        ? plan
        : WorkoutPlanModel(
            id: planId,
            userId: plan.userId,
            splitTitle: plan.splitTitle,
            confidenceScore: plan.confidenceScore,
            source: plan.source,
            summary: plan.summary,
            exercises: plan.exercises,
            generatedAt: plan.generatedAt,
            isCoachApproved: plan.isCoachApproved,
            coachNotes: plan.coachNotes,
          );

    if (Env.useFirebase) {
      try {
        await _firestore.saveWorkoutPlan(model);
      } catch (_) {}
    }
    _localCache.saveWorkoutPlan(model);
  }
}
