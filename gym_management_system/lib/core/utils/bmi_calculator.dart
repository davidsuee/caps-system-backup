class BmiCalculator {
  static double calculateBmi(double weightKg, double heightCm) {
    if (heightCm <= 0 || weightKg <= 0) return 0.0;
    final heightM = heightCm / 100.0;
    return double.parse((weightKg / (heightM * heightM)).toStringAsFixed(1));
  }

  static String getCategory(double bmi) {
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal Weight';
    if (bmi < 30.0) return 'Overweight';
    return 'Obese';
  }

  // Mifflin-St Jeor Formula
  static double calculateBmr({
    required double weightKg,
    required double heightCm,
    required int age,
    required String gender,
  }) {
    double bmr;
    if (gender.toLowerCase() == 'male') {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
    } else {
      bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
    return bmr;
  }

  static double calculateTdee({
    required double bmr,
    required String activityLevel,
  }) {
    double factor = 1.2;
    switch (activityLevel.toLowerCase()) {
      case 'lightly active':
        factor = 1.375;
        break;
      case 'moderately active':
        factor = 1.55;
        break;
      case 'very active':
        factor = 1.725;
        break;
      default:
        factor = 1.2;
    }
    return bmr * factor;
  }

  /// Calculates target daily calories based on TDEE and Fitness Goal
  static double calculateTargetCalories({
    required double tdee,
    required String fitnessGoal,
  }) {
    final goal = fitnessGoal.toLowerCase();
    if (goal.contains('loss')) {
      // 500 kcal deficit for safe fat loss, floor at 1200 kcal
      return (tdee - 500).clamp(1200.0, 5000.0).roundToDouble();
    } else if (goal.contains('gain') || goal.contains('muscle')) {
      // 350 kcal surplus for lean hypertrophy
      return (tdee + 350).clamp(1500.0, 6000.0).roundToDouble();
    } else if (goal.contains('endurance')) {
      return (tdee + 150).clamp(1500.0, 6000.0).roundToDouble();
    }
    return tdee.roundToDouble();
  }

  /// Returns recommended macros (protein, carbs, fat in grams) for target calories and goal
  static ({double protein, double carbs, double fat}) calculateTargetMacros({
    required double targetCalories,
    required String fitnessGoal,
  }) {
    final goal = fitnessGoal.toLowerCase();
    double protRatio;
    double carbRatio;
    double fatRatio;

    if (goal.contains('loss')) {
      protRatio = 0.35; // Higher protein to preserve lean mass during deficit
      carbRatio = 0.35;
      fatRatio = 0.30;
    } else if (goal.contains('gain') || goal.contains('muscle')) {
      protRatio = 0.30;
      carbRatio = 0.45; // Higher carbs for training volume and glycogen
      fatRatio = 0.25;
    } else if (goal.contains('endurance')) {
      protRatio = 0.20;
      carbRatio = 0.55; // High carb fuel for stamina
      fatRatio = 0.25;
    } else {
      protRatio = 0.25;
      carbRatio = 0.45;
      fatRatio = 0.30;
    }

    final p = double.parse(((targetCalories * protRatio) / 4.0).toStringAsFixed(1));
    final c = double.parse(((targetCalories * carbRatio) / 4.0).toStringAsFixed(1));
    final f = double.parse(((targetCalories * fatRatio) / 9.0).toStringAsFixed(1));
    return (protein: p, carbs: c, fat: f);
  }
}

