import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/utils/bmi_calculator.dart';
import '../../../core/utils/facility_hours_helper.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../../workout/providers/workout_provider.dart';
import '../../meal/providers/meal_provider.dart';
import '../../membership/providers/membership_provider.dart';
import '../../../domain/entities/membership_entity.dart';
import '../../progress/providers/progress_provider.dart';
import '../widgets/member_bottom_nav.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen> {


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null) {
        ref.read(membershipNotifierProvider.notifier).loadUserData(user.id);
        ref.read(progressNotifierProvider.notifier).loadLogs(user.id, user: user);

        // Load active workout plan; only auto-generate for a brand new member with no plan at all
        ref.read(workoutNotifierProvider.notifier).loadActivePlan(user.id).then((plan) {
          if (mounted && plan == null && ref.read(workoutNotifierProvider).activePlan == null) {
            ref.read(workoutNotifierProvider.notifier).generatePlan(user);
          }
        });

        // Load active meal plan; only auto-generate for a brand new member with no plan at all
        ref.read(mealNotifierProvider.notifier).loadActivePlan(user.id).then((_) {
          if (mounted && ref.read(mealNotifierProvider).activePlan == null) {
            final bmr = BmiCalculator.calculateBmr(
              weightKg: user.weightKg,
              heightCm: user.heightCm,
              age: user.age,
              gender: user.gender,
            );
            final tdee = BmiCalculator.calculateTdee(bmr: bmr, activityLevel: user.activityLevel);
            final tCal = BmiCalculator.calculateTargetCalories(
              tdee: tdee,
              fitnessGoal: user.fitnessGoal,
              bmi: user.bmi,
            );
            final macros = BmiCalculator.calculateTargetMacros(targetCalories: tCal, fitnessGoal: user.fitnessGoal);

            ref.read(mealNotifierProvider.notifier).generateMealPlan(
              user: user,
              targetCalories: tCal,
              targetProtein: macros.protein,
              targetCarbs: macros.carbs,
              targetFat: macros.fat,
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final workoutState = ref.watch(workoutNotifierProvider);
    final mealState = ref.watch(mealNotifierProvider);
    final memState = ref.watch(membershipNotifierProvider);
    final progressState = ref.watch(progressNotifierProvider);
    final workoutPlan = workoutState.activePlan;
    final mealPlan = mealState.activePlan;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(AppRoutes.welcome);
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final bmi = user.bmi;
    final bmiCategory = BmiCalculator.getCategory(bmi);
    final membership = memState.membership;
    final notifications = LocalCacheService().getNotifications(user.id);

    final logs = progressState.logs;
    final currentWeight = logs.isNotEmpty ? logs.last.weightKg : user.weightKg;
    final initialWeight = logs.length > 1
        ? logs.first.weightKg
        : (logs.isNotEmpty && logs.first.weightKg != user.weightKg
            ? user.weightKg
            : (logs.isNotEmpty ? logs.first.weightKg : user.weightKg));
    final deltaWeight = currentWeight - initialWeight;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Athletic Header Card
              Builder(
                builder: (context) {
                  final formattedName = user.name.trim().isNotEmpty
                      ? user.name.trim().split(' ').map((part) => part.isNotEmpty ? '${part[0].toUpperCase()}${part.substring(1)}' : '').join(' ')
                      : 'Athlete';
                  final todayDateString = DateFormat('EEEE, MMM d').format(DateTime.now()).toUpperCase();

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          context.isDark ? const Color(0xFF161B26) : Colors.white,
                          context.isDark ? const Color(0xFF11141C) : const Color(0xFFF1F5F9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: context.borderLine,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: context.isDark ? 0.25 : 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Left Status Kicker & Greeting
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary.withValues(alpha: 0.75),
                                              blurRadius: 6,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          '$todayDateString • ACTIVE ATHLETE',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Welcome, $formattedName',
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Right Actions (Expiration Countdown, Notification Bell, Theme Toggle, Sign out & Profile Avatar)
                            Row(
                              children: [
                                _ClientExpirationAndNotificationWidget(
                                  userId: user.id,
                                  membership: membership,
                                ),
                                const SizedBox(width: 4),
                                const ThemeToggleButton(),
                                const SizedBox(width: 4),
                                Container(
                                  decoration: BoxDecoration(
                                    color: context.surfaceBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: context.borderLine,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                                    tooltip: 'Sign Out',
                                    onPressed: () async {
                                      context.go(AppRoutes.welcome);
                                      await ref.read(authNotifierProvider.notifier).logout();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () => context.push(AppRoutes.profile),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.primary, width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(alpha: 0.25),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: CircleAvatar(
                                        radius: 19,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                                        child: Text(
                                          formattedName.isNotEmpty ? formattedName[0].toUpperCase() : 'U',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Athletic Goal & Biometrics Badges Strip
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.track_changes_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'GOAL: ${user.fitnessGoal.toUpperCase()}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.surfaceBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.borderLine,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.bolt_rounded, size: 14, color: AppColors.accent),
                                  const SizedBox(width: 5),
                                  Text(
                                    user.activityLevel,
                                    style: TextStyle(
                                      color: context.subtitleColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: context.surfaceBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: context.borderLine,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.monitor_weight_outlined, size: 13, color: context.mutedColor),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${currentWeight.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      color: context.subtitleColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Expiration & Admin Notification Banners
              if (notifications.isNotEmpty) ...[
                ...notifications.map((notif) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notif.title,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notif.message,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          LocalCacheService().dismissNotification(notif.id);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                )),
              ],

              // Dynamic Membership Status Card (No Plan / Pending Cash / Active / Expired)
              if (membership == null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    borderRadius: BorderRadius.circular(20),
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GYM MEMBERSHIP',
                                style: TextStyle(
                                  color: context.subtitleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No Active Membership',
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.push(AppRoutes.membershipPlans),
                            icon: const Icon(Icons.add_card_rounded, size: 16, color: Colors.black),
                            label: const Text('Get Plan', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(90, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Choose a membership plan (Flex, 1-Month, 3-Month, 6-Month Premium, or Elite Founders) and pay cash at the counter to activate access.',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ] else if (membership.isPending) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accent.withValues(alpha: 0.16),
                        context.surfaceBg,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GYM MEMBERSHIP STATUS',
                                style: TextStyle(
                                  color: context.subtitleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No Active Plan (Pending Approval)',
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.accent),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.hourglass_top_rounded, size: 14, color: AppColors.accent),
                                SizedBox(width: 4),
                                Text(
                                  'PENDING CASH',
                                  style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Requested: ${membership.planName}',
                                  style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  '₱${membership.price.toStringAsFixed(0)} Due',
                                  style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your active plan will NOT change or activate until you pay cash at the gym desk and the admin verifies your payment.',
                              style: TextStyle(color: context.subtitleColor, fontSize: 11, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 15, color: AppColors.accent),
                              const SizedBox(width: 6),
                              Text(
                                'Pay cash at reception desk',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.membershipPlans),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              minimumSize: Size.zero,
                            ),
                            child: const Text('Change Plan', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (membership.isActive) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.18),
                        context.surfaceBg,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'GYM MEMBERSHIP STATUS',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                membership.planName,
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => context.push(AppRoutes.attendance),
                            icon: const Icon(Icons.badge_rounded, size: 18, color: Colors.black),
                            label: const Text('Member Pass', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(110, 40),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          const Icon(Icons.event_available_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Expires on: ${DateFormat('MMMM dd, yyyy').format(membership.endDate)}',
                            style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (membership.remainingDays > 5 ? AppColors.primary : AppColors.accent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${membership.remainingDays} DAYS LEFT',
                              style: TextStyle(
                                color: membership.remainingDays > 5 ? AppColors.primary : AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MEMBERSHIP STATUS',
                                style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${membership.planName} (Expired)',
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () => context.push(AppRoutes.membershipPlans),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size(90, 38),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Renew', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your membership expired on ${DateFormat('MMMM dd, yyyy').format(membership.endDate)}. Please renew to access facilities.',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Facility Hours & Member Check-in Live Status Strip
              _buildFacilityCheckInStatusStrip(context, user.id),
              const SizedBox(height: 16),

              // My Gym Visits & Attendance Log (Customer workout frequency)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Gym Visits & Attendance Log',
                            style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track workout frequency and completed sessions',
                            style: TextStyle(color: context.subtitleColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => context.push(AppRoutes.attendance),
                      icon: const Icon(Icons.calendar_month_rounded, size: 14, color: Colors.black),
                      label: const Text('View Log', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Progress & Biometrics Overview
              _SectionHeader(
                title: 'My Fitness Progress',
                actionText: 'View Charts',
                onAction: () => context.push(AppRoutes.progress),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BiometricCard(
                      label: 'Current Weight',
                      value: '$currentWeight kg',
                      subtext: deltaWeight != 0
                          ? '${deltaWeight > 0 ? '+' : ''}${deltaWeight.toStringAsFixed(1)} kg overall'
                          : 'Starting baseline',
                      color: AppColors.primary,
                      icon: Icons.monitor_weight_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BiometricCard(
                      label: 'Body Mass Index (BMI)',
                      value: bmi.toString(),
                      subtext: bmiCategory,
                      color: AppColors.accentCyan,
                      icon: Icons.fitness_center_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Workout Routine Section with Exercise List
              _SectionHeader(
                title: 'My Workout Routine',
                actionText: 'Open Routine',
                onAction: () => context.push(AppRoutes.workoutPlan),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.push(AppRoutes.workoutPlan),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.borderLine),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workoutState.activePlan?.splitTitle ?? 'Personalized Routine',
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    workoutPlan != null
                                        ? '${workoutPlan.exercises.length} Exercises Included'
                                        : 'Generating your workout routine...',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (workoutState.activePlan?.isCoachApproved == true ? AppColors.primary : AppColors.accentCyan)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              workoutState.activePlan?.isCoachApproved == true
                                  ? '✓ COACH APPROVED'
                                  : 'ACTIVE ROUTINE',
                              style: TextStyle(
                                color: workoutState.activePlan?.isCoachApproved == true ? AppColors.primary : AppColors.accentCyan,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (workoutPlan != null) ...[
                        const SizedBox(height: 14),
                        Divider(color: context.borderLine, height: 1),
                        const SizedBox(height: 12),
                        Text(
                          'Exercise Routine List:',
                          style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...List.generate(
                          workoutPlan.exercises.length > 3 ? 3 : workoutPlan.exercises.length,
                          (idx) {
                            final ex = workoutPlan.exercises[idx];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${ex.name} — ${ex.sets} sets x ${ex.reps}',
                                      style: TextStyle(color: context.subtitleColor, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        if (workoutPlan.exercises.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+ ${workoutPlan.exercises.length - 3} more exercises in full routine',
                              style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Meal Plan Section with Meal Breakdown
              _SectionHeader(
                title: 'Nutrition & Meal Plan',
                actionText: 'View All',
                onAction: () => context.push(AppRoutes.mealPlan),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => context.push(AppRoutes.mealPlan),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.surfaceBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.borderLine),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.accent, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mealPlan != null
                                        ? '${mealPlan.totalCalories.toInt()} kcal / day'
                                        : 'Daily Meal Targets',
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    mealPlan != null
                                        ? 'Protein: ${mealPlan.totalProtein.toInt()}g • Carbs: ${mealPlan.totalCarbs.toInt()}g'
                                        : 'Generating nutrition plan...',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (mealState.activePlan?.isCoachApproved == true ? AppColors.primary : AppColors.accent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              mealState.activePlan?.isCoachApproved == true ? '✓ COACH APPROVED' : 'DAILY PLAN',
                              style: TextStyle(
                                color: mealState.activePlan?.isCoachApproved == true ? AppColors.primary : AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (mealPlan != null) ...[
                        const SizedBox(height: 14),
                        Divider(color: context.borderLine, height: 1),
                        const SizedBox(height: 12),
                        Text(
                          'Daily Meal Menu:',
                          style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        ...mealPlan.meals.map((m) {
                          final foodNames = m.items.map((i) => i.name).join(', ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                const Icon(Icons.restaurant_rounded, size: 14, color: AppColors.accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${m.mealName}: $foodNames',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Navigation Action Grid
              Text(
                'Explore Modules',
                style: TextStyle(
                  color: context.titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: isWide ? 4 : 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: isWide ? 3.0 : 2.5,
                    children: [
                      _QuickActionTile(
                        title: 'Workouts',
                        subtitle: 'Routines & Exercises',
                        icon: Icons.fitness_center_rounded,
                        color: AppColors.primary,
                        onTap: () => context.push(AppRoutes.workoutPlan),
                      ),
                      _QuickActionTile(
                        title: 'Meal Plans',
                        subtitle: 'Meals & Nutrition',
                        icon: Icons.restaurant_rounded,
                        color: AppColors.accent,
                        onTap: () => context.push(AppRoutes.mealPlan),
                      ),
                      _QuickActionTile(
                        title: 'Progress',
                        subtitle: 'Weight & Body Fat',
                        icon: Icons.show_chart_rounded,
                        color: AppColors.accentCyan,
                        onTap: () => context.push(AppRoutes.progress),
                      ),
                      _QuickActionTile(
                        title: 'Membership',
                        subtitle: 'Pass & Expiry',
                        icon: Icons.card_membership_rounded,
                        color: Colors.purpleAccent,
                        onTap: () => context.push(AppRoutes.membership),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MemberBottomNav(currentIndex: 0),
    );
  }

  Widget _buildFacilityCheckInStatusStrip(BuildContext context, String userId) {
    final isGymOpen = FacilityHoursHelper.isGymOpen();
    final activeAttendance = LocalCacheService().getActiveAttendance(userId);
    final isCheckedIn = activeAttendance != null;
    final isSessionCompleted = activeAttendance != null &&
        LocalCacheService().isAttendanceSessionCompleted(activeAttendance.id);

    if (!isGymOpen) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'FACILITY CLOSED • Outside Operating Hours',
                    style: TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Operating Hours: 8:00 AM – 11:00 PM Daily. Progress logging is locked while closed.',
                    style: TextStyle(color: context.titleColor, fontSize: 11),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.how_to_reg_rounded, color: Colors.amber, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OUTSIDE GYM • Front Desk Check-In Required',
                    style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check in with admin at gym reception to enable exercise checking and progress logging.',
                    style: TextStyle(color: context.titleColor, fontSize: 11),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WORKOUT PROGRESS COMPLETED • Locked for Visit',
                    style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'You finished today\'s workout session! Check in via admin on your next visit to log again.',
                    style: TextStyle(color: context.titleColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Checked in & in gym
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHECKED IN AT GYM • Active Workout Session',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  'You are checked in! You can now check off exercises in your workout plan.',
                  style: TextStyle(color: context.titleColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final Color color;
  final IconData icon;

  const _BiometricCard({
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderLine),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(color: context.mutedColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: context.titleColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onAction,
            child: Text(
              actionText,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: context.surfaceBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: context.isDark ? 0.18 : 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: context.isDark ? 0.15 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.titleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.mutedColor,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.mutedColor.withValues(alpha: 0.6),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientExpirationAndNotificationWidget extends StatefulWidget {
  final String userId;
  final MembershipEntity? membership;

  const _ClientExpirationAndNotificationWidget({
    required this.userId,
    required this.membership,
  });

  @override
  State<_ClientExpirationAndNotificationWidget> createState() =>
      _ClientExpirationAndNotificationWidgetState();
}

class _ClientExpirationAndNotificationWidgetState
    extends State<_ClientExpirationAndNotificationWidget> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Live moving countdown timer: updates dynamically
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });
    _checkAndSeedExpirationNotice();
  }

  @override
  void didUpdateWidget(covariant _ClientExpirationAndNotificationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membership != widget.membership) {
      _checkAndSeedExpirationNotice();
    }
  }

  void _checkAndSeedExpirationNotice() {
    final mem = widget.membership;
    if (mem == null || !mem.isActive) return;

    final diff = mem.endDate.difference(DateTime.now());
    final isExpired = diff.isNegative;
    final isExpiringSoon = !isExpired && diff.inSeconds <= 7 * 86400;

    if (isExpiringSoon || isExpired) {
      final notifs = LocalCacheService().getNotifications(widget.userId);
      final hasNotice = notifs.any((n) =>
          n.id.startsWith('exp_notice_') ||
          n.title.contains('Expiring') ||
          n.title.contains('Expired'));
      if (!hasNotice) {
        final days = diff.inDays;
        final hours = diff.inHours % 24;
        final countdown = isExpired ? 'Expired' : '${days}d ${hours}h left';
        LocalCacheService().addNotification(
          AppNotificationModel(
            id: 'exp_notice_${widget.userId}',
            userId: widget.userId,
            title: isExpired ? 'Membership Expired' : 'Plan Expiring Soon ($countdown)',
            message: isExpired
                ? 'Your ${mem.planName} has expired. Please renew at the gym counter to regain access.'
                : 'Your ${mem.planName} will expire in $countdown (${DateFormat('MMM d, yyyy').format(mem.endDate)}). Please renew your subscription at the front counter.',
            createdAt: DateTime.now(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDaysAndHours(Duration diff) {
    if (diff.isNegative) return 'Plan Expired';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    if (days > 0) {
      return '${days}d ${hours}h left';
    }
    return '${hours}h left';
  }

  void _openNotificationSheet(
    BuildContext context,
    MembershipEntity? mem,
    bool isExpiringSoon,
    bool isExpired,
    String countdownText,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setSheetState) {
            final currentNotifs = LocalCacheService().getNotifications(widget.userId);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: context.borderLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_active_rounded, color: AppColors.accent, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Notifications & Plan Alerts',
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: context.mutedColor, size: 20),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 7-Day Plan Expiration Alert Card
                  if (mem != null && (isExpiringSoon || isExpired)) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isExpired
                            ? AppColors.error.withValues(alpha: 0.12)
                            : AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isExpired ? AppColors.error : AppColors.accent).withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isExpired ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                                color: isExpired ? AppColors.error : AppColors.accent,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  isExpired ? 'MEMBERSHIP EXPIRED' : 'MEMBERSHIP EXPIRING SOON',
                                  style: TextStyle(
                                    color: isExpired ? AppColors.error : AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (isExpired ? AppColors.error : AppColors.accent).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  countdownText,
                                  style: TextStyle(
                                    color: isExpired ? AppColors.error : AppColors.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isExpired
                                ? 'Your ${mem.planName} has expired. Please renew at the gym counter to regain access.'
                                : 'Your active ${mem.planName} will expire in $countdownText on ${DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(mem.endDate)}.',
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(sheetCtx);
                                context.push(AppRoutes.membershipPlans);
                              },
                              icon: const Icon(Icons.upgrade_rounded, size: 18, color: Colors.black),
                              label: const Text('Renew / Change Membership Plan',
                                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isExpired ? AppColors.error : AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Admin & System Notifications List
                  if (currentNotifs.isNotEmpty) ...[
                    Text(
                      'ADMIN NOTICES',
                      style: TextStyle(
                        color: context.mutedColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(sheetCtx).size.height * 0.35,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: currentNotifs.length,
                        itemBuilder: (ctx, idx) {
                          final notif = currentNotifs[idx];
                          final formattedTime = DateFormat('MMM d, h:mm a').format(notif.createdAt);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.elevatedSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.borderLine),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.campaign_rounded, color: AppColors.accent, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif.title,
                                              style: TextStyle(
                                                color: context.titleColor,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            formattedTime,
                                            style: TextStyle(
                                              color: context.mutedColor,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        notif.message,
                                        style: TextStyle(
                                          color: context.subtitleColor,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    LocalCacheService().dismissNotification(notif.id);
                                    setSheetState(() {});
                                    setState(() {});
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(Icons.close_rounded, size: 16, color: context.mutedColor),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (!(isExpiringSoon || isExpired)) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.mark_email_read_outlined, size: 40, color: context.mutedColor),
                            const SizedBox(height: 8),
                            Text(
                              'You\'re all caught up!',
                              style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No new notifications or alerts from gym administration.',
                              style: TextStyle(color: context.subtitleColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mem = widget.membership;
    final bool hasActivePlan = mem != null && mem.isActive;
    final now = DateTime.now();
    final Duration diff = hasActivePlan ? mem.endDate.difference(now) : Duration.zero;
    final bool isExpired = hasActivePlan && diff.isNegative;
    final bool isExpiringSoon = hasActivePlan && !isExpired && diff.inSeconds <= 7 * 86400;

    final countdownText = hasActivePlan ? _formatDaysAndHours(diff) : '';
    final notifs = LocalCacheService().getNotifications(widget.userId);
    final bool hasAlert = isExpiringSoon || isExpired || notifs.isNotEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Live moving countdown chip: days and hours only (e.g. 6d 14h left)
        if (hasActivePlan && (isExpiringSoon || isExpired)) ...[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _openNotificationSheet(context, mem, isExpiringSoon, isExpired, countdownText),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isExpired
                      ? AppColors.error.withValues(alpha: 0.15)
                      : AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isExpired ? AppColors.error : AppColors.accent,
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isExpired ? AppColors.error : AppColors.accent).withValues(alpha: 0.25),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hourglass_top_rounded,
                      size: 13,
                      color: isExpired ? AppColors.error : AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      countdownText,
                      style: TextStyle(
                        color: isExpired ? AppColors.error : AppColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],

        // Notification Icon Button beside Dark/Light Mode button
        Container(
          decoration: BoxDecoration(
            color: context.surfaceBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasAlert
                  ? (isExpired ? AppColors.error : AppColors.accent)
                  : context.borderLine,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: Icon(
                  hasAlert
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  color: hasAlert
                      ? (isExpired ? AppColors.error : AppColors.accent)
                      : context.titleColor,
                  size: 18,
                ),
                tooltip: isExpiringSoon ? 'Plan Expiring: $countdownText' : 'Notifications',
                onPressed: () => _openNotificationSheet(context, mem, isExpiringSoon, isExpired, countdownText),
              ),
              if (hasAlert)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isExpired ? AppColors.error : AppColors.accent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (isExpired ? AppColors.error : AppColors.accent).withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

