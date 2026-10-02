import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/utils/validators.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../workout/providers/workout_provider.dart';
import '../../meal/providers/meal_provider.dart';
import '../../dashboard/widgets/member_app_bar.dart';
import '../../dashboard/widgets/member_bottom_nav.dart';
import '../../../core/utils/facility_hours_helper.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../providers/progress_provider.dart';

class ProgressTrackingScreen extends ConsumerStatefulWidget {
  const ProgressTrackingScreen({super.key});

  @override
  ConsumerState<ProgressTrackingScreen> createState() => _ProgressTrackingScreenState();
}

class _ProgressTrackingScreenState extends ConsumerState<ProgressTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null) {
        ref.read(progressNotifierProvider.notifier).loadLogs(user.id, user: user);
      }
    });
  }

  void _showAddLogDialog() {
    final isGymOpen = FacilityHoursHelper.isGymOpen();
    if (!isGymOpen) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(FacilityHoursHelper.closedProgressWarning),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    final user = ref.read(authNotifierProvider).user;
    if (user != null) {
      final activeAtt = LocalCacheService().getActiveAttendance(user.id);
      if (activeAtt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(FacilityHoursHelper.checkInRequiredWarning),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      final isSessionCompleted = LocalCacheService().isAttendanceSessionCompleted(activeAtt.id);
      if (isSessionCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(FacilityHoursHelper.sessionAlreadyCompletedWarning),
            backgroundColor: AppColors.accentCyan,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
    }

    final weightController = TextEditingController();
    final bodyFatController = TextEditingController();
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log Biometrics',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.mutedColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: weightController,
                label: 'Weight (kg)',
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
                label: 'Session Notes (optional)',
                hint: 'e.g. Felt strong, good hydration',
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Save Progress Entry',
                onPressed: () async {
                  final w = double.tryParse(weightController.text.trim());
                  if (w == null) return;
                  final user = ref.read(authNotifierProvider).user;
                  if (user == null) return;

                  final bf = double.tryParse(bodyFatController.text.trim());
                  ref.read(progressNotifierProvider.notifier).addLog(
                    userId: user.id,
                    weightKg: w,
                    bodyFat: bf,
                    notes: notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
                    user: user,
                  );

                  Navigator.pop(ctx);

                  // Update active user profile with new bodyweight and trigger AI adaptations
                  final updatedUser = user.copyWith(weightKg: w);
                  await ref.read(authNotifierProvider.notifier).updateProfile(updatedUser);
                  await ref.read(workoutNotifierProvider.notifier).generatePlan(updatedUser);

                  final bmr = BmiCalculator.calculateBmr(
                    weightKg: updatedUser.weightKg,
                    heightCm: updatedUser.heightCm,
                    age: updatedUser.age,
                    gender: updatedUser.gender,
                  );
                  final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: updatedUser.activityLevel);
                  final tCal = BmiCalculator.calculateTargetCalories(tdee: tdee, fitnessGoal: updatedUser.fitnessGoal);
                  final macros = BmiCalculator.calculateTargetMacros(targetCalories: tCal, fitnessGoal: updatedUser.fitnessGoal);

                  await ref.read(mealNotifierProvider.notifier).generateMealPlan(
                    user: updatedUser,
                    targetCalories: tCal,
                    targetProtein: macros.protein,
                    targetCarbs: macros.carbs,
                    targetFat: macros.fat,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Weight logged: ${w}kg! Workout targets & meal calories updated to ${tCal.toInt()} kcal!'),
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final progressState = ref.watch(progressNotifierProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final logs = progressState.logs;
    final currentWeight = logs.isNotEmpty ? logs.last.weightKg : user.weightKg;
    final initialWeight = logs.length > 1
        ? logs.first.weightKg
        : (logs.isNotEmpty && logs.first.weightKg != user.weightKg
            ? user.weightKg
            : (logs.isNotEmpty ? logs.first.weightKg : user.weightKg));
    final delta = currentWeight - initialWeight;

    final isGymOpen = FacilityHoursHelper.isGymOpen();
    final activeAttendance = LocalCacheService().getActiveAttendance(user.id);
    final isCheckedIn = activeAttendance != null;
    final isSessionCompleted = activeAttendance != null &&
        LocalCacheService().isAttendanceSessionCompleted(activeAttendance.id);
    final isLocked = !isGymOpen || !isCheckedIn || isSessionCompleted;

    return Scaffold(
      appBar: MemberAppBar(
        title: 'Progress Tracking',
        subtitle: 'Body Metrics & Weigh-In Logs',
        icon: Icons.show_chart_rounded,
        actions: [
          Container(
            decoration: BoxDecoration(
              color: isLocked
                  ? context.cardColor
                  : AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isLocked
                    ? context.borderLine
                    : AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: IconButton(
              icon: Icon(
                isLocked ? Icons.lock_outline_rounded : Icons.add_rounded,
                color: isLocked ? context.mutedColor : AppColors.primary,
                size: 20,
              ),
              tooltip: isLocked
                  ? (!isGymOpen
                      ? 'Locked: Gym closed (6:00 AM – 11:00 PM)'
                      : (!isCheckedIn
                          ? 'Locked: Check-in required at front desk'
                          : 'Locked: Session progress completed'))
                  : 'Log Biometrics',
              onPressed: _showAddLogDialog,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // Check-in & Facility Operating Hours Gate Banner
            _buildCheckInGateBanner(
              context: context,
              isGymOpen: isGymOpen,
              isCheckedIn: isCheckedIn,
              isSessionCompleted: isSessionCompleted,
            ),

            // Stats Header Cards
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    title: 'Current Weight',
                    value: '$currentWeight kg',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    title: 'Total Change',
                    value: '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                    color: delta <= 0 ? AppColors.primary : AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // FlChart Line Chart Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.borderLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Weight Trend (kg)',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Recorded biometric weigh-in progression',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 200,
                    child: logs.length < 2
                        ? const Center(
                            child: Text(
                              'Add at least two logs to see your trend graph',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                            ),
                          )
                        : LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: 2,
                                getDrawingHorizontalLine: (val) => FlLine(
                                  color: context.borderLine,
                                  strokeWidth: 1,
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    getTitlesWidget: (val, meta) => Text(
                                      '${val.toInt()}',
                                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (val, meta) {
                                      final index = val.toInt();
                                      if (index >= 0 && index < logs.length) {
                                        return Text(
                                          DateFormat('M/d').format(logs[index].date),
                                          style: TextStyle(color: context.mutedColor, fontSize: 10),
                                        );
                                      }
                                      return const Text('');
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: List.generate(
                                    logs.length,
                                    (i) => FlSpot(i.toDouble(), logs[i].weightKg),
                                  ),
                                  isCurved: true,
                                  color: AppColors.primary,
                                  barWidth: 3,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: true),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Log History
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Log History',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                TextButton.icon(
                  onPressed: _showAddLogDialog,
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text('Add Entry', style: TextStyle(color: AppColors.primary, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...logs.reversed.map((log) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderLine),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.scale_rounded, color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('MMMM d, yyyy').format(log.date),
                            style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if ((log.notes ?? '').isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              log.notes ?? '',
                              style: TextStyle(color: context.mutedColor, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${log.weightKg} kg',
                    style: const TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
      bottomNavigationBar: const MemberBottomNav(currentIndex: 3),
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
                    'Operating Hours: 6:00 AM – 11:00 PM Daily.\nBiometric progress logging is disabled outside operating hours because you are not inside the gym.',
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
                    'You are not checked in to the gym. Please check in with the admin at the front reception desk before you can log new biometric progress entries.',
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
                    'You have completed your workout progress for this gym visit. Biometrics and session tracking are locked. Check in via the admin module on your next visit to log progress again.',
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
              'CHECKED IN • Live gym session active. Tap the "+" button above to log your weigh-in.',
              style: TextStyle(color: context.titleColor, fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatTile({required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
