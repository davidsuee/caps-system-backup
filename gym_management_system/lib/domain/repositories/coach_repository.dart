import '../../data/models/user_model.dart';
import '../../data/models/workout_plan_model.dart';
import '../../data/models/meal_plan_model.dart';
import '../../data/datasources/local/local_cache_service.dart';

abstract class CoachRepository {
  List<UserModel> getCachedAssignedClients();
  Map<String, WorkoutPlanModel?> getCachedWorkoutPlans();
  Map<String, MealPlanModel?> getCachedMealPlans();
  Future<List<UserModel>> getAssignedClients();
  Future<Map<String, WorkoutPlanModel?>> getAllClientWorkoutPlans();
  Future<Map<String, MealPlanModel?>> getAllClientMealPlans();
  Future<WorkoutPlanModel?> getClientWorkoutPlan(String clientUserId);
  Future<MealPlanModel?> getClientMealPlan(String clientUserId);
  Future<void> approveWorkoutPlan(String clientUserId, {String? notes});
  Future<void> approveMealPlan(String clientUserId, {String? notes});
  Future<List<TrainingSessionModel>> getCoachSessions(String coachId);
  Future<void> scheduleSession(TrainingSessionModel session);
}
