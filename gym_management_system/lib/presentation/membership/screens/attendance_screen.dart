import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/membership_provider.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  Timer? _liveTimer;
  Timer? _cloudSyncTimer;

  @override
  void initState() {
    super.initState();
    // Load fresh data immediately on screen open
    Future.microtask(() {
      final user = ref.read(authNotifierProvider).user;
      if (user != null && mounted) {
        ref.read(membershipNotifierProvider.notifier).loadUserData(user.id);
      }
    });

    // Tick every second for live duration ticker & auto-closing check
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final autoClosed = LocalCacheService().autoCheckOutClosedSessions();
        if (autoClosed) {
          final user = ref.read(authNotifierProvider).user;
          if (user != null) {
            ref.read(membershipNotifierProvider.notifier).loadUserData(user.id);
          }
        }
        setState(() {});
      }
    });

    // Live sync every 5 seconds for real-time tracking
    _cloudSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      final user = ref.read(authNotifierProvider).user;
      if (user != null && mounted) {
        ref.read(membershipNotifierProvider.notifier).loadUserData(user.id);
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _cloudSyncTimer?.cancel();
    super.dispose();
  }

  String _formatLiveDuration(DateTime checkInTime) {
    final diff = DateTime.now().difference(checkInTime);
    if (diff.isNegative) return '00m 00s';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    final secs = diff.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final memState = ref.watch(membershipNotifierProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final membership = memState.membership ?? LocalCacheService().getMembership(user.id);
    final history = memState.attendanceHistory;
    final isCheckedIn = memState.isCurrentlyCheckedIn;
    final activeSession = memState.activeAttendance;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        title: const Text('Digital Member Pass'),
        actions: [
          const ThemeToggleButton(),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Sync Real-Time Data',
            onPressed: () => ref.read(membershipNotifierProvider.notifier).loadUserData(user.id),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // Digital Member Pass Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isCheckedIn ? AppColors.primary.withValues(alpha: 0.6) : context.borderLine,
                  width: isCheckedIn ? 1.8 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCheckedIn ? AppColors.primary : Colors.black)
                        .withValues(alpha: context.isDark ? 0.12 : 0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
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
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'VICIOUS DIGITAL MEMBER PASS',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: (membership != null ? AppColors.primary : AppColors.accent).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          membership != null ? 'ACTIVE MEMBER' : 'REGISTERED',
                          style: TextStyle(
                            color: membership != null ? AppColors.primary : AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Member Identity Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.18),
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'M',
                          style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: TextStyle(
                                color: context.titleColor,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ID: ${user.id.toUpperCase()}',
                              style: TextStyle(color: context.mutedColor, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                            ),
                            if (user.fitnessGoal.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '${user.fitnessGoal} • ${user.experienceLevel}',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Divider(color: context.borderLine),
                  const SizedBox(height: 14),

                  // Membership Plan Details Row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEMBERSHIP PLAN',
                              style: TextStyle(color: context.mutedColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              membership?.planName ?? 'No Active Plan',
                              style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      if (membership != null)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'VALIDITY / EXPIRATION',
                                style: TextStyle(color: context.mutedColor, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM dd, yyyy').format(membership.endDate),
                                style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live In-Gym Status Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCheckedIn
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCheckedIn
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : context.borderLine,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCheckedIn ? AppColors.primary : context.mutedColor,
                            boxShadow: isCheckedIn
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isCheckedIn ? 'CURRENTLY INSIDE GYM' : 'NOT CURRENTLY IN GYM',
                                style: TextStyle(
                                  color: isCheckedIn ? AppColors.primary : context.subtitleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isCheckedIn && activeSession != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Time-In: ${DateFormat('hh:mm a').format(activeSession.checkInTime)} • Active Duration: ${_formatLiveDuration(activeSession.checkInTime)}',
                                  style: TextStyle(color: context.titleColor, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Front Desk Staff Instructions Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Front Desk Attendance Logging',
                                style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Please state your Name or Member ID to the front desk reception upon entry. The gym staff will log your Time-In at the terminal. All active sessions automatically log Time-Out at 11:00 PM closing time.',
                                style: TextStyle(color: context.subtitleColor, fontSize: 11, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Operating Hours Info Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: AppColors.accent),
                        SizedBox(width: 8),
                        Text(
                          'Facility Hours: 8:00 AM – 11:00 PM Daily',
                          style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance History',
                  style: TextStyle(color: context.titleColor, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${history.length} Total Visits',
                  style: TextStyle(color: context.mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderLine),
                ),
                child: Center(
                  child: Text(
                    'No check-in history yet. Visit the front desk to check in when you arrive at the gym!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.mutedColor, fontSize: 13),
                  ),
                ),
              )
            else
              ...history.map((item) {
                final isCompleted = item.checkOutTime != null;
                final durationStr = isCompleted
                    ? '${item.checkOutTime!.difference(item.checkInTime).inMinutes} min session'
                    : 'Active (${_formatLiveDuration(item.checkInTime)})';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCompleted ? context.borderLine : AppColors.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isCompleted ? AppColors.primary : AppColors.accent)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isCompleted ? Icons.done_all_rounded : Icons.timer_outlined,
                          color: isCompleted ? AppColors.primary : AppColors.accent,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(item.checkInTime),
                              style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCompleted
                                  ? 'In: ${DateFormat('hh:mm a').format(item.checkInTime)} • Out: ${DateFormat('hh:mm a').format(item.checkOutTime!)} ($durationStr)'
                                  : 'In: ${DateFormat('hh:mm a').format(item.checkInTime)} • $durationStr',
                              style: TextStyle(color: context.subtitleColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isCompleted ? AppColors.primary : AppColors.accent)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isCompleted ? 'COMPLETED' : 'IN SESSION',
                          style: TextStyle(
                            color: isCompleted ? AppColors.primary : AppColors.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
