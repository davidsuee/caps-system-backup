class FoodItemEntity {
  final String foodId;
  final String name;
  final String category;
  final double servings;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double cost;

  const FoodItemEntity({
    required this.foodId,
    required this.name,
    required this.category,
    required this.servings,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.cost,
  });
}

class MealSlotEntity {
  final String mealName; // Breakfast, Lunch, Dinner, Snack
  final List<FoodItemEntity> items;
  final double slotCalories;
  final double slotProtein;
  final double slotCarbs;
  final double slotFat;
  final double slotCost;

  const MealSlotEntity({
    required this.mealName,
    required this.items,
    required this.slotCalories,
    required this.slotProtein,
    required this.slotCarbs,
    required this.slotFat,
    required this.slotCost,
  });

  String get name => mealName;
}

class MealPlanEntity {
  final String id;
  final String userId;
  final String source; // "optimization_lp_v1"
  final double totalCalories;
  final double targetCalories;
  final double totalProtein;
  final double targetProtein;
  final double totalCarbs;
  final double targetCarbs;
  final double totalFat;
  final double targetFat;
  final double totalCost;
  final double? budgetLimit;
  final bool isFeasible;
  final String solverMessage;
  final List<MealSlotEntity> meals;
  final DateTime generatedAt;
  final bool isCoachApproved;
  final String? coachNotes;

  const MealPlanEntity({
    required this.id,
    required this.userId,
    required this.source,
    required this.totalCalories,
    required this.targetCalories,
    required this.totalProtein,
    required this.targetProtein,
    required this.totalCarbs,
    required this.targetCarbs,
    required this.totalFat,
    required this.targetFat,
    required this.totalCost,
    this.budgetLimit,
    required this.isFeasible,
    required this.solverMessage,
    required this.meals,
    required this.generatedAt,
    this.isCoachApproved = false,
    this.coachNotes,
  });

  MealPlanEntity copyWith({
    String? id,
    String? userId,
    String? source,
    double? totalCalories,
    double? targetCalories,
    double? totalProtein,
    double? targetProtein,
    double? totalCarbs,
    double? targetCarbs,
    double? totalFat,
    double? targetFat,
    double? totalCost,
    double? budgetLimit,
    bool? isFeasible,
    String? solverMessage,
    List<MealSlotEntity>? meals,
    DateTime? generatedAt,
    bool? isCoachApproved,
    String? coachNotes,
  }) {
    return MealPlanEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      source: source ?? this.source,
      totalCalories: totalCalories ?? this.totalCalories,
      targetCalories: targetCalories ?? this.targetCalories,
      totalProtein: totalProtein ?? this.totalProtein,
      targetProtein: targetProtein ?? this.targetProtein,
      totalCarbs: totalCarbs ?? this.totalCarbs,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      totalFat: totalFat ?? this.totalFat,
      targetFat: targetFat ?? this.targetFat,
      totalCost: totalCost ?? this.totalCost,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      isFeasible: isFeasible ?? this.isFeasible,
      solverMessage: solverMessage ?? this.solverMessage,
      meals: meals ?? this.meals,
      generatedAt: generatedAt ?? this.generatedAt,
      isCoachApproved: isCoachApproved ?? this.isCoachApproved,
      coachNotes: coachNotes ?? this.coachNotes,
    );
  }
}
