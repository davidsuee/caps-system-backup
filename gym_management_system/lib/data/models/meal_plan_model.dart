import '../../domain/entities/meal_plan_entity.dart';

class FoodItemModel extends FoodItemEntity {
  const FoodItemModel({
    required super.foodId,
    required super.name,
    required super.category,
    required super.servings,
    required super.servingUnit,
    required super.calories,
    required super.protein,
    required super.carbs,
    required super.fat,
    required super.cost,
  });

  factory FoodItemModel.fromJson(Map<String, dynamic> json) {
    return FoodItemModel(
      foodId: json['food_id'] ?? json['foodId'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      servings: (json['servings'] as num?)?.toDouble() ?? 1.0,
      servingUnit: json['serving_unit'] ?? json['servingUnit'] ?? 'serving',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0.0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food_id': foodId,
      'name': name,
      'category': category,
      'servings': servings,
      'serving_unit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'cost': cost,
    };
  }
}

class MealSlotModel extends MealSlotEntity {
  const MealSlotModel({
    required super.mealName,
    required super.items,
    required super.slotCalories,
    required super.slotProtein,
    required super.slotCarbs,
    required super.slotFat,
    required super.slotCost,
  });

  factory MealSlotModel.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? <dynamic>[];
    final List<FoodItemEntity> itemsList = rawItems
        .map<FoodItemEntity>((i) => FoodItemModel.fromJson(Map<String, dynamic>.from(i as Map)))
        .toList();

    return MealSlotModel(
      mealName: (json['meal_name'] ?? json['mealName'] ?? '').toString(),
      items: itemsList,
      slotCalories: ((json['slot_calories'] ?? json['slotCalories']) as num?)?.toDouble() ?? 0.0,
      slotProtein: ((json['slot_protein'] ?? json['slotProtein']) as num?)?.toDouble() ?? 0.0,
      slotCarbs: ((json['slot_carbs'] ?? json['slotCarbs']) as num?)?.toDouble() ?? 0.0,
      slotFat: ((json['slot_fat'] ?? json['slotFat']) as num?)?.toDouble() ?? 0.0,
      slotCost: ((json['slot_cost'] ?? json['slotCost']) as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'meal_name': mealName,
      'items': items.map((i) => (i is FoodItemModel ? i : FoodItemModel(
        foodId: i.foodId,
        name: i.name,
        category: i.category,
        servings: i.servings,
        servingUnit: i.servingUnit,
        calories: i.calories,
        protein: i.protein,
        carbs: i.carbs,
        fat: i.fat,
        cost: i.cost,
      )).toJson()).toList(),
      'slot_calories': slotCalories,
      'slot_protein': slotProtein,
      'slot_carbs': slotCarbs,
      'slot_fat': slotFat,
      'slot_cost': slotCost,
    };
  }
}

class MealPlanModel extends MealPlanEntity {
  const MealPlanModel({
    required super.id,
    required super.userId,
    required super.source,
    required super.totalCalories,
    required super.targetCalories,
    required super.totalProtein,
    required super.targetProtein,
    required super.totalCarbs,
    required super.targetCarbs,
    required super.totalFat,
    required super.targetFat,
    required super.totalCost,
    super.budgetLimit,
    required super.isFeasible,
    required super.solverMessage,
    required super.meals,
    required super.generatedAt,
    super.isCoachApproved,
    super.coachNotes,
  });

  factory MealPlanModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final rawMeals = (json['meals'] as List?) ?? <dynamic>[];
    final List<MealSlotEntity> mealSlots = rawMeals
        .map<MealSlotEntity>((m) => MealSlotModel.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();

    final planId = (id != null && id.isNotEmpty)
        ? id
        : (json['id'] != null && json['id'].toString().isNotEmpty)
            ? json['id'].toString()
            : 'meal_${DateTime.now().millisecondsSinceEpoch}';

    return MealPlanModel(
      id: planId,
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      source: (json['source'] ?? 'optimization_lp_v1').toString(),
      totalCalories: ((json['total_calories'] ?? json['totalCalories']) as num?)?.toDouble() ?? 0.0,
      targetCalories: ((json['target_calories'] ?? json['targetCalories']) as num?)?.toDouble() ?? 2000.0,
      totalProtein: ((json['total_protein'] ?? json['totalProtein']) as num?)?.toDouble() ?? 0.0,
      targetProtein: ((json['target_protein'] ?? json['targetProtein']) as num?)?.toDouble() ?? 150.0,
      totalCarbs: ((json['total_carbs'] ?? json['totalCarbs']) as num?)?.toDouble() ?? 0.0,
      targetCarbs: ((json['target_carbs'] ?? json['targetCarbs']) as num?)?.toDouble() ?? 200.0,
      totalFat: ((json['total_fat'] ?? json['totalFat']) as num?)?.toDouble() ?? 0.0,
      targetFat: ((json['target_fat'] ?? json['targetFat']) as num?)?.toDouble() ?? 60.0,
      totalCost: ((json['total_cost'] ?? json['totalCost']) as num?)?.toDouble() ?? 0.0,
      budgetLimit: ((json['budget_limit'] ?? json['budgetLimit']) as num?)?.toDouble(),
      isFeasible: json['feasible'] ?? json['isFeasible'] ?? true,
      solverMessage: (json['solver_message'] ?? json['solverMessage'] ?? 'Solved').toString(),
      meals: mealSlots,
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isCoachApproved: json['isCoachApproved'] == true,
      coachNotes: json['coachNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'source': source,
      'total_calories': totalCalories,
      'target_calories': targetCalories,
      'total_protein': totalProtein,
      'target_protein': targetProtein,
      'total_carbs': totalCarbs,
      'target_carbs': targetCarbs,
      'total_fat': totalFat,
      'target_fat': targetFat,
      'total_cost': totalCost,
      'budget_limit': budgetLimit,
      'is_feasible': isFeasible,
      'solver_message': solverMessage,
      'meals': meals.map((m) => (m is MealSlotModel ? m : MealSlotModel(
        mealName: m.mealName,
        items: m.items,
        slotCalories: m.slotCalories,
        slotProtein: m.slotProtein,
        slotCarbs: m.slotCarbs,
        slotFat: m.slotFat,
        slotCost: m.slotCost,
      )).toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'isCoachApproved': isCoachApproved,
      'coachNotes': coachNotes,
    };
  }

  @override
  MealPlanModel copyWith({
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
    return MealPlanModel(
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

