import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/workout_provider.dart';
import '../widgets/exercise_card.dart';

class WorkoutPlanScreen extends ConsumerStatefulWidget {
  const WorkoutPlanScreen({super.key});

  @override
  ConsumerState<WorkoutPlanScreen> createState() => _WorkoutPlanScreenState();
}

class _WorkoutPlanScreenState extends ConsumerState<WorkoutPlanScreen> {
  String? _selectedDayTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final user = ref.read(authNotifierProvider).user;
      if (user != null) {
        if (ref.read(workoutNotifierProvider).activePlan == null) {
          final plan = await ref.read(workoutNotifierProvider.notifier).loadActivePlan(user.id);
          if (plan == null && mounted) {
            await ref.read(workoutNotifierProvider.notifier).generatePlan(user);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final workoutState = ref.watch(workoutNotifierProvider);

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    final plan = workoutState.activePlan;

    final allDayTags = <String>[];
    if (plan != null) {
      for (final ex in plan.exercises) {
        if (ex.dayTag.isNotEmpty && !allDayTags.contains(ex.dayTag)) {
          allDayTags.add(ex.dayTag);
        }
      }
    }

    final activeDay = (_selectedDayTag != null && allDayTags.contains(_selectedDayTag))
        ? _selectedDayTag!
        : (allDayTags.isNotEmpty ? allDayTags.first : null);

    final displayedExercises = (plan != null && activeDay != null && allDayTags.length > 1)
        ? plan.exercises.where((e) => e.dayTag == activeDay).toList()
        : (plan?.exercises ?? []);

    final completedCount = displayedExercises.where((e) => e.isCompleted).length;
    final totalCount = displayedExercises.length;
    final completionRatio = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Workout Routine'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Regenerate Routine',
            onPressed: () => ref.read(workoutNotifierProvider.notifier).generatePlan(user),
          ),
        ],
      ),
      body: workoutState.isLoading
          ? const LoadingIndicator(message: 'Generating your custom workout routine...')
          : workoutState.errorMessage != null && plan == null
              ? ErrorView(
                  message: workoutState.errorMessage!,
                  onRetry: () => ref.read(workoutNotifierProvider.notifier).generatePlan(user),
                )
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      // Routine Summary Banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          plan?.splitTitle ?? 'Personalized Routine',
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (plan?.isCoachApproved == true ? AppColors.primary : AppColors.accent).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    plan?.isCoachApproved == true ? '✓ Coach Approved' : 'Personalized Plan',
                                    style: TextStyle(
                                      color: plan?.isCoachApproved == true ? AppColors.primary : AppColors.accent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              plan?.summary ?? 'Tailored routine configured for your fitness goal and biometric stats.',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'AI Goal Matched',
                                    style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Target: ${user.fitnessGoal}',
                                  style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            if (totalCount > 0) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Session Progress: $completedCount of $totalCount exercises completed',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                  Text(
                                    '${(completionRatio * 100).toInt()}%',
                                    style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: completionRatio,
                                backgroundColor: AppColors.surfaceLight,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                borderRadius: BorderRadius.circular(6),
                                minHeight: 7,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Customer-friendly Generate / Refresh Button
                      CustomButton(
                        text: plan == null ? 'Generate Workout Routine' : 'Refresh Workout Routine',
                        icon: Icons.auto_awesome_rounded,
                        onPressed: () => ref.read(workoutNotifierProvider.notifier).generatePlan(user),
                      ),
                      const SizedBox(height: 24),

                      if (plan != null && plan.exercises.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              allDayTags.length > 1
                                  ? (activeDay ?? 'Exercise Schedule & Sets')
                                  : (allDayTags.isNotEmpty ? allDayTags.first : 'Exercise Schedule & Sets'),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${displayedExercises.length} ${displayedExercises.length == 1 ? 'Exercise' : 'Exercises'}${allDayTags.length > 1 ? ' (${plan.exercises.length} Total)' : ''}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Day Split Selector Tabs
                        if (allDayTags.length > 1) ...[
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: allDayTags.map((tag) {
                                final isSelected = tag == activeDay;
                                final dayExercises = plan.exercises.where((e) => e.dayTag == tag).toList();
                                final dayDone = dayExercises.where((e) => e.isCompleted).length;
                                final isDayCompleted = dayExercises.isNotEmpty && dayDone == dayExercises.length;

                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedDayTag = tag;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.surfaceLight,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : AppColors.border,
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDayCompleted
                                                ? Icons.check_circle_rounded
                                                : (isSelected ? Icons.fitness_center_rounded : Icons.calendar_today_rounded),
                                            size: 15,
                                            color: isSelected ? Colors.black : (isDayCompleted ? AppColors.primary : AppColors.textSecondary),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            tag,
                                            style: TextStyle(
                                              color: isSelected ? Colors.black : AppColors.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.black.withValues(alpha: 0.15) : AppColors.surface,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$dayDone/${dayExercises.length}',
                                              style: TextStyle(
                                                color: isSelected ? Colors.black : AppColors.textMuted,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        ...List.generate(
                          displayedExercises.length,
                          (index) {
                            final exercise = displayedExercises[index];
                            return ExerciseCard(
                              exercise: exercise,
                              onToggle: () => ref.read(workoutNotifierProvider.notifier).toggleExerciseCompletion(exercise),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }
}
