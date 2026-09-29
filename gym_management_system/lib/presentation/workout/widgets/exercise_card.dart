import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/workout_plan_entity.dart';

class ExerciseCard extends StatelessWidget {
  final ExerciseEntity exercise;
  final VoidCallback onToggle;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exercise.isCompleted ? AppColors.surfaceLight.withValues(alpha: 0.5) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exercise.isCompleted ? AppColors.primary.withValues(alpha: 0.5) : AppColors.border,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onToggle,
            icon: Icon(
              exercise.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: exercise.isCompleted ? AppColors.primary : AppColors.textMuted,
              size: 26,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: TextStyle(
                    color: exercise.isCompleted ? AppColors.textMuted : AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    decoration: exercise.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (exercise.dayTag.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          exercise.dayTag,
                          style: const TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        exercise.muscleGroup,
                        style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${exercise.sets} sets × ${exercise.reps} reps',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.fitness_center_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      exercise.equipment,
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(width: 14),
                    Icon(Icons.timer_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${exercise.restSec}s rest',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                if (exercise.instructions != null && exercise.instructions!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: exercise.instructions!.contains('Unilateral')
                          ? Colors.cyanAccent.withValues(alpha: 0.08)
                          : AppColors.background.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: exercise.instructions!.contains('Unilateral')
                            ? Colors.cyanAccent.withValues(alpha: 0.25)
                            : AppColors.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          exercise.instructions!.contains('Unilateral')
                              ? Icons.alt_route_rounded
                              : Icons.info_outline_rounded,
                          size: 13,
                          color: exercise.instructions!.contains('Unilateral')
                              ? Colors.cyanAccent
                              : AppColors.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            exercise.instructions!,
                            style: TextStyle(
                              color: exercise.instructions!.contains('Unilateral')
                                  ? Colors.cyanAccent.withValues(alpha: 0.9)
                                  : AppColors.textSecondary,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
