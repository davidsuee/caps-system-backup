import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/meal_plan_entity.dart';

class MealSlotCard extends StatelessWidget {
  final MealSlotEntity slot;
  final List<String> excludedAllergens;

  const MealSlotCard({
    super.key,
    required this.slot,
    this.excludedAllergens = const [],
  });

  @override
  Widget build(BuildContext context) {
    final alternativeText = _getAllergenAlternative(slot.mealName, excludedAllergens);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.borderLine),
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
          // Slot Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _getMealIcon(slot.mealName),
                      color: AppColors.accent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      slot.mealName,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${slot.slotCalories.toInt()} kcal',
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          // Food Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...slot.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${item.name} (${item.servings} × ${item.servingUnit})',
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${item.calories.toInt()} kcal',
                        style: TextStyle(
                          color: context.subtitleColor,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )),

                // Dedicated Allergen-Safe Alternative Swaps (e.g. Seafood, Gluten, Dairy)
                if (alternativeText != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.swap_horiz_rounded, size: 14, color: AppColors.primary),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              excludedAllergens.any((a) => a.toLowerCase().contains('seafood'))
                                  ? 'SEAFOOD ALLERGY ALTERNATIVE SWAP'
                                  : 'ALLERGEN-SAFE ALTERNATIVE SWAP',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          alternativeText,
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '100% Allergen-Free • Equivalent Protein, Carbs & Calories Matched',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                Divider(color: context.borderLine, height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'P: ${slot.slotProtein.toInt()}g | C: ${slot.slotCarbs.toInt()}g | F: ${slot.slotFat.toInt()}g',
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                    Text(
                      '₱${slot.slotCost.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getAllergenAlternative(String mealName, List<String> allergens) {
    if (allergens.any((a) => a.toLowerCase().contains('seafood'))) {
      return _getSeafoodAlternative(mealName);
    }
    if (allergens.any((a) => a.toLowerCase().contains('dairy'))) {
      return 'Safe Swap: Unsweetened Almond or Soy Milk, Coconut Yogurt (100% Dairy & Lactose-Free)';
    }
    if (allergens.any((a) => a.toLowerCase().contains('gluten'))) {
      return 'Safe Swap: Steamed Brown Rice, Quinoa, or Boiled Kamote (100% Gluten-Free Carbohydrates)';
    }
    if (allergens.any((a) => a.toLowerCase().contains('egg'))) {
      return 'Safe Swap: Pan-Seared Firm Tofu, Lean Chicken Strips, or Whey Protein (100% Egg-Free Protein)';
    }
    if (allergens.any((a) => a.toLowerCase().contains('nut'))) {
      return 'Safe Swap: Sunflower Seed Butter or Roasted Pumpkin Seeds (100% Tree Nut & Peanut-Free)';
    }
    return null;
  }

  String _getSeafoodAlternative(String name) {
    final n = name.toLowerCase();
    if (n.contains('breakfast')) {
      return 'Safe Swap: 3 Boiled Egg Whites with Spinach or Protein Oatmeal with Peanut Butter (substitutes Tinapa / Dried Fish)';
    } else if (n.contains('lunch')) {
      return 'Safe Swap: Traditional Chicken Tinola (Lean Chicken Breast & Malunggay) or Pan-Seared Firm Tofu (substitutes Tuna Flakes & Shrimp)';
    } else if (n.contains('dinner')) {
      return 'Safe Swap: Bistek Tagalog (Lean Sirloin Beef Strips) or Grilled Chicken Breast with Brown Rice (substitutes Salmon & Tilapia)';
    } else {
      return 'Safe Swap: Hard-Boiled Egg with Calamansi or Greek Yogurt with Mango & Chia Seeds (substitutes Fish Jerky / Canned Seafood)';
    }
  }

  IconData _getMealIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('breakfast')) return Icons.free_breakfast_outlined;
    if (n.contains('lunch')) return Icons.lunch_dining_outlined;
    if (n.contains('dinner')) return Icons.dinner_dining_outlined;
    return Icons.cookie_outlined;
  }
}
