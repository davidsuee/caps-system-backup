import '../entities/workout_plan_entity.dart';
import '../entities/user_entity.dart';

abstract class WorkoutRepository {
  Future<WorkoutPlanEntity> generateWorkoutRecommendation(UserEntity user);
  Future<WorkoutPlanEntity?> getActiveWorkoutPlan(String userId);
  Future<void> saveWorkoutPlan(WorkoutPlanEntity plan);
}
