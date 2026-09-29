import '../entities/user_entity.dart';
import '../entities/meal_plan_entity.dart';
import '../repositories/meal_repository.dart';

class GenerateMealPlanUseCase {
  final MealRepository repository;
  GenerateMealPlanUseCase(this.repository);

  Future<MealPlanEntity> execute({
    required UserEntity user,
    required double targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    List<String> dietaryRestrictions = const [],
    double? budgetLimit,
  }) {
    return repository.generateMealPlanOptimization(
      user: user,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbs: targetCarbs,
      targetFat: targetFat,
      dietaryRestrictions: dietaryRestrictions,
      budgetLimit: budgetLimit,
    );
  }
}
