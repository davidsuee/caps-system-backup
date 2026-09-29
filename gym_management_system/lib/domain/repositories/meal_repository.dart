import '../entities/meal_plan_entity.dart';
import '../entities/user_entity.dart';

abstract class MealRepository {
  Future<MealPlanEntity> generateMealPlanOptimization({
    required UserEntity user,
    required double targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    List<String> dietaryRestrictions,
    double? budgetLimit,
  });
  Future<MealPlanEntity?> getActiveMealPlan(String userId);
  Future<void> saveMealPlan(MealPlanEntity plan);
}
