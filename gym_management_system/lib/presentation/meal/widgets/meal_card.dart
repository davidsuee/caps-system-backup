import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/meal_plan_entity.dart';

class MealSlotCard extends StatelessWidget {
  final MealSlotEntity slot;

  const MealSlotCard({super.key, required this.slot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slot Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${item.calories.toInt()} kcal',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(color: AppColors.border, height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'P: ${slot.slotProtein.toInt()}g | C: ${slot.slotCarbs.toInt()}g | F: ${slot.slotFat.toInt()}g',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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

  IconData _getMealIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('breakfast')) return Icons.free_breakfast_outlined;
    if (n.contains('lunch')) return Icons.lunch_dining_outlined;
    if (n.contains('dinner')) return Icons.dinner_dining_outlined;
    return Icons.cookie_outlined;
  }
}
