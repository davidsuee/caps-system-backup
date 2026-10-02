import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../dashboard/widgets/member_app_bar.dart';
import '../../dashboard/widgets/member_bottom_nav.dart';
import '../providers/meal_provider.dart';
import '../widgets/meal_card.dart';

class MealPlanScreen extends ConsumerStatefulWidget {
  const MealPlanScreen({super.key});

  @override
  ConsumerState<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends ConsumerState<MealPlanScreen> {
  final List<String> _selectedAllergens = [];
  double _targetCalories = 2100;
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
        final bmr = BmiCalculator.calculateBmr(
          weightKg: user.weightKg,
          heightCm: user.heightCm,
          age: user.age,
          gender: user.gender,
        );
        final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);
        final calculatedTarget = BmiCalculator.calculateTargetCalories(tdee: tdee, fitnessGoal: user.fitnessGoal);
        setState(() {
          _targetCalories = calculatedTarget;
        });

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final mealState = ref.watch(mealNotifierProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final plan = mealState.activePlan;

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
                                      plan != null ? '${plan.totalCalories.toInt()} kcal / day' : '${_targetCalories.toInt()} kcal Target',
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
                                    plan?.isCoachApproved == true ? 'âœ“ Coach Approved' : 'Balanced Diet',
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
                              plan?.solverMessage ?? 'Optimized macronutrient balance tailored for ${user.fitnessGoal}.',
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
                                _MacroBadge('Est. Cost', 'â‚±${plan?.totalCost.toStringAsFixed(0) ?? _budgetLimit.toInt()}', Colors.purpleAccent),
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

                      // Calorie Slider
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Adjust Daily Calorie Target', style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${_targetCalories.toInt()} kcal', style: const TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      Slider(
                        value: _targetCalories,
                        min: 1400,
                        max: 3800,
                        divisions: 24,
                        activeColor: AppColors.accent,
                        inactiveColor: context.elevatedSurface,
                        onChanged: (v) => setState(() => _targetCalories = v),
                      ),

                      const SizedBox(height: 12),
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
    final macros = BmiCalculator.calculateTargetMacros(
      targetCalories: _targetCalories,
      fitnessGoal: user.fitnessGoal,
    );
    ref.read(mealNotifierProvider.notifier).generateMealPlan(
      user: user,
      targetCalories: _targetCalories,
      targetProtein: macros.protein,
      targetCarbs: macros.carbs,
      targetFat: macros.fat,
      dietaryRestrictions: _selectedAllergens,
      budgetLimit: _budgetLimit,
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
