import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/providers/auth_provider.dart';
import '../../dashboard/widgets/member_app_bar.dart';
import '../../dashboard/widgets/member_bottom_nav.dart';
import '../../admin/providers/facility_provider.dart';
import '../../../domain/services/exercise_alternative_service.dart';
import '../../../core/utils/facility_hours_helper.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../core/utils/app_feedback_helper.dart';
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
    final facilityState = ref.watch(facilityNotifierProvider);
    final alternativeService = ref.watch(exerciseAlternativeServiceProvider);

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

    final occupiedExercises = displayedExercises.where((ex) {
      return alternativeService.isEquipmentOccupied(
        ex,
        equipment: facilityState.equipment,
        facilities: facilityState.facilities,
      );
    }).toList();

    final completedCount = displayedExercises.where((e) => e.isCompleted).length;
    final totalCount = displayedExercises.length;
    final completionRatio = totalCount > 0 ? completedCount / totalCount : 0.0;

    final isGymOpen = FacilityHoursHelper.isGymOpen();
    final activeAttendance = LocalCacheService().getActiveAttendance(user.id);
    final isCheckedIn = activeAttendance != null;
    final isSessionCompleted = activeAttendance != null &&
        LocalCacheService().isAttendanceSessionCompleted(activeAttendance.id);
    final isLocked = !isGymOpen || !isCheckedIn || isSessionCompleted;
    final lockReason = !isGymOpen
        ? 'Gym is closed (Hours: 6:00 AM – 11:00 PM)'
        : (!isCheckedIn
            ? 'Must be checked in at reception desk'
            : 'Session progress completed');

    return Scaffold(
      appBar: MemberAppBar(
        title: 'Workout Routine',
        subtitle: 'AI Training Split & Exercises',
        icon: Icons.fitness_center_rounded,
        actions: [
          Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderLine),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 18),
              tooltip: 'Regenerate Routine',
              onPressed: () => ref.read(workoutNotifierProvider.notifier).generatePlan(user),
            ),
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
                      // Gym Operating Hours & Reception Check-In Enforcement Banner
                      _buildCheckInGateBanner(
                        context: context,
                        isGymOpen: isGymOpen,
                        isCheckedIn: isCheckedIn,
                        isSessionCompleted: isSessionCompleted,
                      ),

                      // Routine Summary Banner
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
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
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 24),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          plan?.splitTitle ?? 'Personalized Routine',
                                          style: TextStyle(
                                            color: context.titleColor,
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
                              style: TextStyle(color: context.subtitleColor, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: context.elevatedSurface,
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
                                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
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
                                backgroundColor: context.elevatedSurface,
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
                        if (occupiedExercises.isNotEmpty) ...[
                          Builder(builder: (context) {
                            final hasMaintenance = occupiedExercises.any((ex) =>
                                alternativeService.isEquipmentUnderMaintenance(
                                  ex,
                                  equipment: facilityState.equipment,
                                ));
                            return Container(
                              margin: const EdgeInsets.only(bottom: 18),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.warning.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      hasMaintenance ? Icons.build_rounded : Icons.bolt_rounded,
                                      color: AppColors.warning,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          hasMaintenance
                                              ? '${occupiedExercises.length} ${occupiedExercises.length == 1 ? 'Equipment' : 'Equipments'} Under Maintenance or Busy'
                                              : '${occupiedExercises.length} ${occupiedExercises.length == 1 ? 'Machine is' : 'Machines are'} Currently Occupied',
                                          style: const TextStyle(
                                            color: AppColors.warning,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          hasMaintenance
                                              ? 'In-gym alternatives are ready. Tap "Select Alternative" to switch to an available operational exercise!'
                                              : 'AI biomechanical alternatives are ready. Tap "Get AI Alternative" on any busy machine to continue training without waiting!',
                                          style: TextStyle(
                                            color: context.titleColor,
                                            fontSize: 11,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              allDayTags.length > 1
                                  ? (activeDay ?? 'Exercise Schedule & Sets')
                                  : (allDayTags.isNotEmpty ? allDayTags.first : 'Exercise Schedule & Sets'),
                              style: TextStyle(
                                color: context.titleColor,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${displayedExercises.length} ${displayedExercises.length == 1 ? 'Exercise' : 'Exercises'}${allDayTags.length > 1 ? ' (${plan.exercises.length} Total)' : ''}',
                              style: TextStyle(color: context.mutedColor, fontSize: 12),
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
                                            : context.elevatedSurface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? AppColors.primary : context.borderLine,
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
                                            color: isSelected ? Colors.black : (isDayCompleted ? AppColors.primary : context.subtitleColor),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            tag,
                                            style: TextStyle(
                                              color: isSelected ? Colors.black : context.titleColor,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Colors.black.withValues(alpha: 0.15) : context.cardColor,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$dayDone/${dayExercises.length}',
                                              style: TextStyle(
                                                color: isSelected ? Colors.black : context.mutedColor,
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
                              isLocked: isLocked,
                              lockReason: lockReason,
                              onToggle: () {
                                if (!isGymOpen) {
                                  AppFeedbackHelper.showWarning(
                                    context,
                                    message: FacilityHoursHelper.closedProgressWarning,
                                  );
                                  return;
                                }
                                if (!isCheckedIn) {
                                  AppFeedbackHelper.showCheckInWarning(
                                    context,
                                    message: FacilityHoursHelper.checkInRequiredWarning,
                                  );
                                  return;
                                }
                                if (isSessionCompleted) {
                                  AppFeedbackHelper.showInfo(
                                    context,
                                    title: 'SESSION COMPLETED',
                                    message: FacilityHoursHelper.sessionAlreadyCompletedWarning,
                                  );
                                  return;
                                }

                                ref.read(workoutNotifierProvider.notifier).toggleExerciseCompletion(exercise);

                                // Check if this completion finishes all exercises in the current routine
                                final willBeCompleted = !exercise.isCompleted;
                                if (willBeCompleted) {
                                  final otherIncomplete = displayedExercises.where((e) => e.name != exercise.name && !e.isCompleted).length;
                                  if (otherIncomplete == 0) {
                                    LocalCacheService().markAttendanceSessionCompleted(activeAttendance.id);
                                    setState(() {});
                                    AppFeedbackHelper.showSuccess(
                                      context,
                                      title: 'SESSION FINISHED',
                                      message: '🎉 Outstanding! You completed all exercises for this gym visit. Your progress is saved and locked until your next check-in at reception!',
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                        if (isCheckedIn && !isSessionCompleted && completedCount > 0) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                LocalCacheService().markAttendanceSessionCompleted(activeAttendance.id);
                                setState(() {});
                                AppFeedbackHelper.showSuccess(
                                  context,
                                  title: 'PROGRESS LOCKED',
                                  message: 'Workout progress finished & locked for this gym visit! Check in again via admin reception on your next visit to log progress.',
                                );
                              },
                              icon: const Icon(Icons.done_all_rounded, color: Colors.black, size: 20),
                              label: const Text(
                                'Finish & Lock Today\'s Workout Progress',
                                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
      bottomNavigationBar: const MemberBottomNav(currentIndex: 1),
    );
  }

  Widget _buildCheckInGateBanner({
    required BuildContext context,
    required bool isGymOpen,
    required bool isCheckedIn,
    required bool isSessionCompleted,
  }) {
    if (!isGymOpen) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.6), width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GYM IS CLOSED (Outside Operating Hours)',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Operating Hours: 6:00 AM – 11:00 PM Daily.\nProgress checking & exercise completions are strictly disabled outside operating hours because you are not inside the gym.',
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
      );
    }

    if (!isCheckedIn) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.how_to_reg_rounded, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NOT CHECKED IN AT RECEPTION',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You are not checked in to the gym. Please check in with the admin at the front reception desk before you can check off exercises or log your workout progress.',
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
      );
    }

    if (isSessionCompleted) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.6), width: 1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TODAY\'S PROGRESS COMPLETED & SAVED',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You have finished your workout progress for this gym visit. Your routine is saved and locked. To log progress again, check in via the admin module on your next visit.',
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
      );
    }

    // Checked in & active
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'CHECKED IN • Gym visit active. Tap the circle next to each exercise as you finish your sets.',
              style: TextStyle(color: context.titleColor, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
