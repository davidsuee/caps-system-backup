import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../dashboard/widgets/member_app_bar.dart';
import '../../dashboard/widgets/member_bottom_nav.dart';
import '../../progress/providers/progress_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../providers/meal_provider.dart';
import '../widgets/meal_card.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  final List<String> _selectedAllergens = [];
  final double _budgetLimit = 350;

  final List<String> _availableAllergens = ['Gluten', 'Dairy', 'Nuts', 'Eggs', 'Seafood'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null) {
        if (user.dietaryRestrictions.isNotEmpty && _selectedAllergens.isEmpty) {
          _selectedAllergens.addAll(user.dietaryRestrictions);
        }

        if (ref.read(mealNotifierProvider).activePlan == null) {
          ref.read(mealNotifierProvider.notifier).loadActivePlan(user.id).then((loaded) {
            if (mounted && loaded == null && ref.read(mealNotifierProvider).activePlan == null) {
              _runOptimizer();
            }
          });
        }
      }
    });
  }

  double _computeTargetCalories(dynamic user) {
    final bmr = BmiCalculator.calculateBmr(
      weightKg: user.weightKg,
      heightCm: user.heightCm,
      age: user.age,
      gender: user.gender,
    );
    final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);
    return BmiCalculator.calculateTargetCalories(
      tdee: tdee,
      fitnessGoal: user.fitnessGoal,
      bmi: user.bmi,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final mealState = ref.watch(mealNotifierProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final plan = mealState.activePlan;
    final bmr = BmiCalculator.calculateBmr(
      weightKg: user.weightKg,
      heightCm: user.heightCm,
      age: user.age,
      gender: user.gender,
    );
    final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);
    final calculatedCalories = _computeTargetCalories(user);
    final currentCalories = plan != null ? plan.totalCalories : calculatedCalories;
    final bmi = user.bmi;
    final bmiCategory = BmiCalculator.getCategory(bmi);

    return Scaffold(
      appBar: MemberAppBar(
        title: 'Nutrition & Meal Plan',
        subtitle: 'PuLP Optimized Diet & Macros',
        icon: Icons.restaurant_rounded,
        actions: [
          Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderLine),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
              tooltip: 'Regenerate Plan',
              onPressed: () => _runOptimizer(),
            ),
          ),
        ],
      ),
      body: mealState.isLoading
          ? const LoadingIndicator(message: 'Designing your personalized nutrition plan...')
          : mealState.errorMessage != null && plan == null
              ? ErrorView(
                  message: mealState.errorMessage!,
                  onRetry: _runOptimizer,
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Target Macro Summary Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.restaurant_menu_rounded, color: AppColors.accent, size: 24),
                                    const SizedBox(width: 10),
                                    Text(
                                      '${currentCalories.toInt()} kcal / day',
                                      style: TextStyle(
                                        color: context.titleColor,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (plan?.isCoachApproved == true ? AppColors.primary : AppColors.accent).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    plan?.isCoachApproved == true ? '\u2713 Coach Approved' : 'Balanced Diet',
                                    style: TextStyle(
                                      color: plan?.isCoachApproved == true ? AppColors.primary : AppColors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              plan?.solverMessage ??
                                  'Optimal macronutrient balance tailored for ${user.fitnessGoal} (${user.activityLevel} lifestyle: ${currentCalories.toInt()} kcal).',
                              style: TextStyle(color: context.subtitleColor, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _MacroBadge('Protein', '${plan?.totalProtein.toInt() ?? 150}g', AppColors.primary),
                                const SizedBox(width: 8),
                                _MacroBadge('Carbs', '${plan?.totalCarbs.toInt() ?? 210}g', AppColors.accentCyan),
                                const SizedBox(width: 8),
                                _MacroBadge('Fats', '${plan?.totalFat.toInt() ?? 60}g', AppColors.accent),
                                const SizedBox(width: 8),
                                _MacroBadge('Est. Cost', '\u20B1${plan?.totalCost.toStringAsFixed(0) ?? _budgetLimit.toInt()}', Colors.purpleAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Allergen & Dietary Restriction Chips
                      Text(
                        'Exclude Allergens / Dietary Preferences',
                        style: TextStyle(color: context.titleColor, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableAllergens.map((allergen) {
                          final isSelected = _selectedAllergens.contains(allergen);
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: FilterChip(
                              label: Text(allergen),
                              selected: isSelected,
                              selectedColor: AppColors.primary.withValues(alpha: 0.20),
                              checkmarkColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? AppColors.primary : context.subtitleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                              backgroundColor: context.elevatedSurface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: isSelected ? AppColors.primary : context.borderLine,
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedAllergens.add(allergen);
                                  } else {
                                    _selectedAllergens.remove(allergen);
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Calorie Target Card (Locked to Member BMI & Fitness Goal)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.calculate_rounded, color: AppColors.accent, size: 18),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Daily Calorie Target',
                                      style: TextStyle(
                                        color: context.titleColor,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded, color: Colors.amber, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'Locked to BMI & Goal',
                                        style: TextStyle(
                                          color: Colors.amber,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  '${currentCalories.toInt()} kcal',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '/ day target',
                                  style: TextStyle(color: context.mutedColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _BadgeChip(
                                  icon: Icons.monitor_weight_outlined,
                                  label: 'BMI: ${bmi.toStringAsFixed(1)} ($bmiCategory)',
                                  color: AppColors.primary,
                                ),
                                _BadgeChip(
                                  icon: Icons.flag_rounded,
                                  label: 'Goal: ${user.fitnessGoal}',
                                  color: AppColors.accentCyan,
                                ),
                                _BadgeChip(
                                  icon: Icons.local_fire_department_rounded,
                                  label: BmiCalculator.getGoalCalorieAdjustmentDescription(user.fitnessGoal, bmi),
                                  color: AppColors.accent,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.elevatedSurface.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: context.borderLine.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.info_outline_rounded, color: context.mutedColor, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Target calories are determined automatically from your BMI, BMR (${bmr.toInt()} kcal), TDEE (${tdee.toInt()} kcal), and fitness goal. Direct manual adjustment is disabled. Your calorie target will only change when you log an improvement or update your biometrics.',
                                      style: TextStyle(color: context.subtitleColor, fontSize: 12, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.trending_up_rounded, size: 16),
                                    label: const Text('Log Improvement'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(color: AppColors.primary),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _showLogImprovementSheet(user),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.tune_rounded, size: 16),
                                  label: const Text('Edit Goal'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: context.subtitleColor,
                                    side: BorderSide(color: context.borderLine),
                                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => context.go(AppRoutes.profile),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      CustomButton(
                        text: plan == null ? 'Generate Daily Meal Plan' : 'Refresh Daily Meal Plan',
                        icon: Icons.restaurant_rounded,
                        color: AppColors.accent,
                        onPressed: _runOptimizer,
                      ),
                      const SizedBox(height: 24),

                      if (plan != null && plan.meals.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Daily Meal Breakdown',
                              style: TextStyle(
                                color: context.titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${plan.meals.length} Meals Scheduled',
                              style: TextStyle(color: context.mutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Dietary Safeguard & Allergy Substitution Notification Banner
                        if (_selectedAllergens.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.40)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Allergy Safeguards Active: ${_selectedAllergens.join(', ')} Excluded',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _selectedAllergens.contains('Seafood')
                                            ? 'All fish, tuna, salmon, bangus, and shellfish are excluded. Safe high-protein alternatives (Lean Chicken Tinola, Tofu, Lean Sirloin) are active in each meal breakdown below.'
                                            : 'Excluded ingredients have been swapped out. Check each meal slot below for safe alternatives matched to your daily macro targets.',
                                        style: TextStyle(color: context.subtitleColor, fontSize: 11, height: 1.35),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        ...plan.meals.map((slot) => MealSlotCard(
                          slot: slot,
                          excludedAllergens: _selectedAllergens,
                        )),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
      bottomNavigationBar: const MemberBottomNav(currentIndex: 2),
    );
  }

  void _runOptimizer() {
    final user = ref.read(authNotifierProvider).user;
    if (user == null) return;
    final targetCalories = _computeTargetCalories(user);
    final macros = BmiCalculator.calculateTargetMacros(
      targetCalories: targetCalories,
      fitnessGoal: user.fitnessGoal,
    );
    ref.read(mealNotifierProvider.notifier).generateMealPlan(
      user: user,
      targetCalories: targetCalories,
      targetProtein: macros.protein,
      targetCarbs: macros.carbs,
      targetFat: macros.fat,
      dietaryRestrictions: _selectedAllergens,
      budgetLimit: _budgetLimit,
    );
  }

  void _showLogImprovementSheet(dynamic user) {
    final weightController = TextEditingController(text: user.weightKg.toStringAsFixed(1));
    final bodyFatController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.trending_up_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Set Progress Improvement',
                        style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.mutedColor),
                    onPressed: () => Navigator.pop(sheetCtx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Log your new weight to recalculate your BMI and automatically calibrate your daily calorie and macronutrient targets.',
                style: TextStyle(color: context.subtitleColor, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: weightController,
                label: 'Current Weight (kg)',
                hint: 'e.g. 71.5',
                keyboardType: TextInputType.number,
                validator: (v) => Validators.number(v, 'Enter valid weight'),
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: bodyFatController,
                label: 'Body Fat % (optional)',
                hint: 'e.g. 15.2',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              CustomTextField(
                controller: notesController,
                label: 'Improvement Notes (optional)',
                hint: 'e.g. Weight improvement, feeling leaner',
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Save Improvement & Update Calories',
                icon: Icons.check_circle_outline_rounded,
                onPressed: () async {
                  final w = double.tryParse(weightController.text.trim());
                  if (w == null || w <= 0) return;
                  final bf = double.tryParse(bodyFatController.text.trim());
                  final notes = notesController.text.trim().isNotEmpty ? notesController.text.trim() : null;

                  // 1. Add log to progress provider
                  ref.read(progressNotifierProvider.notifier).addLog(
                    userId: user.id,
                    weightKg: w,
                    bodyFat: bf,
                    notes: notes,
                    user: user,
                  );

                  Navigator.pop(sheetCtx);

                  // 2. Update active user profile with new bodyweight
                  final updatedUser = user.copyWith(weightKg: w);
                  await ref.read(authNotifierProvider.notifier).updateProfile(updatedUser);

                  // 3. Trigger AI workout adaptations
                  await ref.read(workoutNotifierProvider.notifier).generatePlan(updatedUser);

                  // 4. Calculate new BMR, TDEE, Calories based on new BMI and Goal
                  final bmr = BmiCalculator.calculateBmr(
                    weightKg: updatedUser.weightKg,
                    heightCm: updatedUser.heightCm,
                    age: updatedUser.age,
                    gender: updatedUser.gender,
                  );
                  final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: updatedUser.activityLevel);
                  final tCal = BmiCalculator.calculateTargetCalories(
                    tdee: tdee,
                    fitnessGoal: updatedUser.fitnessGoal,
                    bmi: updatedUser.bmi,
                  );
                  final macros = BmiCalculator.calculateTargetMacros(
                    targetCalories: tCal,
                    fitnessGoal: updatedUser.fitnessGoal,
                  );

                  // 5. Generate updated meal plan
                  await ref.read(mealNotifierProvider.notifier).generateMealPlan(
                    user: updatedUser,
                    targetCalories: tCal,
                    targetProtein: macros.protein,
                    targetCarbs: macros.carbs,
                    targetFat: macros.fat,
                    dietaryRestrictions: _selectedAllergens,
                    budgetLimit: _budgetLimit,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Improvement saved! Weight: ${w}kg • BMI: ${updatedUser.bmi} • Calories updated to ${tCal.toInt()} kcal!'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
