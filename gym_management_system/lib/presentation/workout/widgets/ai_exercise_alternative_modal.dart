import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/workout_plan_entity.dart';
import '../../../domain/services/exercise_alternative_service.dart';
import '../../admin/providers/facility_provider.dart';
import '../providers/workout_provider.dart';

class AiExerciseAlternativeModal extends ConsumerWidget {
  final ExerciseEntity exercise;
  final VoidCallback? onSwapped;

  const AiExerciseAlternativeModal({
    super.key,
    required this.exercise,
    this.onSwapped,
  });

  static Future<void> show(
    BuildContext context, {
    required ExerciseEntity exercise,
    VoidCallback? onSwapped,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AiExerciseAlternativeModal(
        exercise: exercise,
        onSwapped: onSwapped,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(facilityNotifierProvider);
    final service = ref.watch(exerciseAlternativeServiceProvider);

    final notice = service.getOccupancyNotice(
      exercise,
      equipment: facilityState.equipment,
      facilities: facilityState.facilities,
    );
    final isOccupied = notice != null;

    final alternatives = service.getAlternatives(
      exercise: exercise,
      equipment: facilityState.equipment,
      facilities: facilityState.facilities,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: context.borderLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.4 : 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: context.mutedColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.accent],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Exercise Alternative',
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Smart substitution for ${exercise.name}',
                          style: TextStyle(
                            color: context.subtitleColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: context.mutedColor),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Main Content ScrollView
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // Equipment Status Notification Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.accentCyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOccupied
                            ? AppColors.warning.withValues(alpha: 0.35)
                            : AppColors.accentCyan.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isOccupied
                              ? Icons.fmd_bad_rounded
                              : Icons.info_outline_rounded,
                          color: isOccupied ? AppColors.warning : AppColors.accentCyan,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOccupied
                                    ? 'Facility / Equipment Alert'
                                    : 'Active Workout Substitution',
                                style: TextStyle(
                                  color: isOccupied ? AppColors.warning : AppColors.accentCyan,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notice ??
                                    '${exercise.equipment} is part of your workout. If the machine is occupied by another member or has a queue, use an AI biomechanical alternative below!',
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 12,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Recommended Alternatives (${alternatives.length})',
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...alternatives.map((alt) => _buildAlternativeCard(context, ref, alt)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativeCard(
    BuildContext context,
    WidgetRef ref,
    AlternativeRecommendation alt,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: alt.matchPercentage >= 95
              ? AppColors.primary.withValues(alpha: 0.4)
              : context.borderLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match badge and alternative name
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  alt.alternativeName,
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded, size: 13, color: AppColors.primary),
                    const SizedBox(width: 3),
                    Text(
                      '${alt.matchPercentage}% Match',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Equipment & Target Tags
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildTag(
                context,
                icon: Icons.fitness_center_outlined,
                label: alt.alternativeEquipment,
                color: AppColors.accent,
              ),
              _buildTag(
                context,
                icon: Icons.accessibility_new_rounded,
                label: alt.muscleGroup,
                color: AppColors.accentCyan,
              ),
              _buildTag(
                context,
                icon: Icons.repeat_rounded,
                label: '${alt.sets} sets × ${alt.reps}',
                color: AppColors.primary,
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Instructions
          Text(
            alt.instructions,
            style: TextStyle(
              color: context.subtitleColor,
              fontSize: 12,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 10),

          // AI Rationale Callout
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderLine),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  color: AppColors.primary,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'AI Rationale: ',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(
                          text: alt.aiRationale,
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Swap Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final newExercise = alt.toExerciseEntity(dayTag: exercise.dayTag);
                ref
                    .read(workoutNotifierProvider.notifier)
                    .swapExercise(exercise, newExercise);

                Navigator.pop(context);
                if (onSwapped != null) {
                  onSwapped!();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: context.cardColor,
                    behavior: SnackBarBehavior.floating,
                    content: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Swapped to ${alt.alternativeName} in your active workout!',
                            style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Swap to this Exercise in Workout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
