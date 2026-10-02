import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_feedback_helper.dart';
import '../../../domain/entities/workout_plan_entity.dart';
import '../../../domain/services/exercise_alternative_service.dart';
import '../../admin/providers/facility_provider.dart';
import 'ai_exercise_alternative_modal.dart';

class ExerciseCard extends ConsumerWidget {
  final ExerciseEntity exercise;
  final VoidCallback onToggle;
  final bool isLocked;
  final String? lockReason;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onToggle,
    this.isLocked = false,
    this.lockReason,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(facilityNotifierProvider);
    final alternativeService = ref.watch(exerciseAlternativeServiceProvider);

    final occupancyNotice = alternativeService.getOccupancyNotice(
      exercise,
      equipment: facilityState.equipment,
      facilities: facilityState.facilities,
    );
    final isOccupied = occupancyNotice != null;
    final isUnderMaintenance = alternativeService.isEquipmentUnderMaintenance(
      exercise,
      equipment: facilityState.equipment,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: exercise.isCompleted
            ? context.elevatedSurface.withValues(alpha: 0.5)
            : context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: exercise.isCompleted
              ? AppColors.primary.withValues(alpha: 0.5)
              : (isOccupied
                  ? AppColors.warning.withValues(alpha: 0.6)
                  : context.borderLine),
          width: isOccupied ? 1.5 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () {
                  if (isUnderMaintenance) {
                    AppFeedbackHelper.showWarning(
                      context,
                      title: 'UNDER MAINTENANCE',
                      message: 'This equipment is currently under maintenance. Please select an alternative exercise.',
                    );
                    AiExerciseAlternativeModal.show(context, exercise: exercise);
                    return;
                  }
                  onToggle();
                },
                tooltip: isUnderMaintenance
                    ? 'Equipment under maintenance (Alternative available)'
                    : (isLocked ? (lockReason ?? 'Progress checking locked') : null),
                icon: Icon(
                  exercise.isCompleted
                      ? Icons.check_circle_rounded
                      : (isUnderMaintenance
                          ? Icons.build_rounded
                          : (isLocked ? Icons.lock_outline_rounded : Icons.radio_button_unchecked_rounded)),
                  color: exercise.isCompleted
                      ? AppColors.primary
                      : (isUnderMaintenance
                          ? AppColors.warning
                          : (isLocked ? context.mutedColor.withValues(alpha: 0.6) : context.mutedColor)),
                  size: 26,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: TextStyle(
                              color: exercise.isCompleted
                                  ? context.mutedColor
                                  : context.titleColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              decoration: exercise.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isOccupied)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUnderMaintenance ? Icons.build_rounded : Icons.fmd_bad_rounded,
                                  size: 11,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isUnderMaintenance ? 'Under Maintenance' : 'Machine Busy',
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (exercise.dayTag.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              exercise.dayTag,
                              style: const TextStyle(
                                  color: AppColors.accent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            exercise.muscleGroup,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${exercise.sets} sets × ${exercise.reps} reps',
                            style: TextStyle(
                                color: context.subtitleColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.fitness_center_outlined,
                            size: 14, color: context.mutedColor),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            exercise.equipment,
                            style: TextStyle(
                                color: isOccupied
                                    ? AppColors.warning
                                    : context.mutedColor,
                                fontSize: 12,
                                fontWeight: isOccupied
                                    ? FontWeight.w700
                                    : FontWeight.normal),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Icon(Icons.timer_outlined,
                            size: 14, color: context.mutedColor),
                        const SizedBox(width: 4),
                        Text(
                          '${exercise.restSec}s rest',
                          style: TextStyle(
                              color: context.mutedColor, fontSize: 12),
                        ),
                      ],
                    ),
                    if (exercise.instructions != null &&
                        exercise.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: exercise.instructions!.contains('Unilateral')
                              ? Colors.cyanAccent.withValues(alpha: 0.08)
                              : (exercise.instructions!.contains('AI Alternative')
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : context.elevatedSurface),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: exercise.instructions!.contains('Unilateral')
                                ? Colors.cyanAccent.withValues(alpha: 0.25)
                                : (exercise.instructions!.contains('AI Alternative')
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : context.borderLine),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              exercise.instructions!.contains('AI Alternative')
                                  ? Icons.auto_awesome_rounded
                                  : (exercise.instructions!.contains('Unilateral')
                                      ? Icons.alt_route_rounded
                                      : Icons.info_outline_rounded),
                              size: 13,
                              color: exercise.instructions!.contains('AI Alternative')
                                  ? AppColors.primary
                                  : (exercise.instructions!.contains('Unilateral')
                                      ? Colors.cyanAccent
                                      : context.mutedColor),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                exercise.instructions!,
                                style: TextStyle(
                                  color: exercise.instructions!.contains('AI Alternative')
                                      ? AppColors.primary
                                      : (exercise.instructions!.contains('Unilateral')
                                          ? Colors.cyanAccent.withValues(alpha: 0.9)
                                          : context.subtitleColor),
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

          // Machine Occupied Alert Notice & Swap Button Action
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isOccupied
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : context.elevatedSurface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isOccupied
                    ? AppColors.warning.withValues(alpha: 0.3)
                    : context.borderLine.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isUnderMaintenance
                      ? Icons.build_rounded
                      : (isOccupied ? Icons.fmd_bad_rounded : Icons.psychology_outlined),
                  size: 15,
                  color: isOccupied ? AppColors.warning : AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    occupancyNotice ?? 'Machine busy or in-use on floor?',
                    style: TextStyle(
                      color: isOccupied ? AppColors.warning : context.mutedColor,
                      fontSize: 11,
                      fontWeight: isOccupied ? FontWeight.w600 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    AiExerciseAlternativeModal.show(context, exercise: exercise);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? AppColors.warning.withValues(alpha: 0.15)
                          : AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOccupied ? AppColors.warning : AppColors.primary,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 13,
                          color: isOccupied ? AppColors.warning : AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isUnderMaintenance
                              ? 'Select Alternative'
                              : (isOccupied ? 'Get AI Alternative' : 'AI Alternative'),
                          style: TextStyle(
                            color: isOccupied ? AppColors.warning : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
