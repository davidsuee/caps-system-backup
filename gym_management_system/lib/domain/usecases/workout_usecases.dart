import '../entities/user_entity.dart';
import '../entities/workout_plan_entity.dart';
import '../repositories/workout_repository.dart';

class GenerateWorkoutPlanUseCase {
  final WorkoutRepository repository;
  GenerateWorkoutPlanUseCase(this.repository);

  Future<WorkoutPlanEntity> execute(UserEntity user) {
    return repository.generateWorkoutRecommendation(user);
  }
}
