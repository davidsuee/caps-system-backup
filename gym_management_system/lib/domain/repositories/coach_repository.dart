import '../../data/models/user_model.dart';
import '../../data/models/workout_plan_model.dart';
import '../../data/models/meal_plan_model.dart';
import '../../data/datasources/local/local_cache_service.dart';

abstract class CoachRepository {
  List<UserModel> getCachedAssignedClients([String? coachId]);
  Map<String, WorkoutPlanModel?> getCachedWorkoutPlans([String? coachId]);
  Map<String, MealPlanModel?> getCachedMealPlans([String? coachId]);
  Future<List<UserModel>> getAssignedClients([String? coachId]);
  Future<Map<String, WorkoutPlanModel?>> getAllClientWorkoutPlans([String? coachId]);
  Future<Map<String, MealPlanModel?>> getAllClientMealPlans([String? coachId]);
  Future<WorkoutPlanModel?> getClientWorkoutPlan(String clientUserId);
  Future<MealPlanModel?> getClientMealPlan(String clientUserId);
  Future<void> approveWorkoutPlan(String clientUserId, {String? notes});
  Future<void> approveMealPlan(String clientUserId, {String? notes});
  Future<List<TrainingSessionModel>> getCoachSessions(String coachId);
  Future<void> scheduleSession(TrainingSessionModel session);
  Future<void> cancelSession(String sessionId);
}
