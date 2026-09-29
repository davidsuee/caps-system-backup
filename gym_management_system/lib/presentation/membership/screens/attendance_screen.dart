import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
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

    // Tick every second for live workout duration counter
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    // Live cloud sync every 5 seconds for real-time Firebase tracking
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

  void _showTurnstileScanModal(BuildContext context, String userId, bool isCheckedIn) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan Gym Turnstile Terminal',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Point your camera or tap below to scan gate QR',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Simulated Gate Camera Viewfinder
              Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCheckedIn ? Icons.sensor_door_outlined : Icons.sensor_door_rounded,
                          size: 48,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'SCANNING TURNSTILE QR CODE...',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gate Terminal ID: VISCOUS-ENTRANCE-GATE-01',
                          style: TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ],
                    ),
                    // Scanner reticle corners
                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.primary, width: 3), left: BorderSide(color: AppColors.primary, width: 3)))),
                    ),
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.primary, width: 3), right: BorderSide(color: AppColors.primary, width: 3)))),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 3), left: BorderSide(color: AppColors.primary, width: 3)))),
                    ),
                    Positioned(
                      bottom: 14,
                      right: 14,
                      child: Container(width: 24, height: 24, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 3), right: BorderSide(color: AppColors.primary, width: 3)))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: isCheckedIn ? 'Tap to Confirm Check-Out (Time-Out)' : 'Tap to Confirm Check-In (Time-In)',
                icon: isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  if (isCheckedIn) {
                    await ref.read(membershipNotifierProvider.notifier).checkOut(userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gate Turnstile Check-Out Confirmed! Rest well!'),
                          backgroundColor: AppColors.accent,
                        ),
                      );
                    }
                  } else {
                    await ref.read(membershipNotifierProvider.notifier).checkIn(userId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gate Turnstile Check-In Confirmed! Welcome to VISCOUS Gym!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final memState = ref.watch(membershipNotifierProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    final history = memState.attendanceHistory;
    final isCheckedIn = memState.isCurrentlyCheckedIn;
    final activeSession = memState.activeAttendance;

    // Authentic QR Payload format for digital barcode scanners & mobile scanners
    final qrPayload = 'VISCOUS:ACCESS_PASS:${user.id}:${user.name}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gym Check-In & Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Sync Real-Time Data',
            onPressed: () => ref.read(membershipNotifierProvider.notifier).loadUserData(user.id),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            // QR Pass Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isCheckedIn ? AppColors.primary.withValues(alpha: 0.6) : AppColors.border,
                  width: isCheckedIn ? 1.8 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isCheckedIn ? AppColors.primary : Colors.black).withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'VISCOUS DIGITAL ACCESS PASS',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isCheckedIn ? AppColors.primary : AppColors.surfaceLight).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_tethering_rounded,
                              size: 11,
                              color: isCheckedIn ? AppColors.primary : AppColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isCheckedIn ? 'LIVE SESSION' : 'OFFLINE',
                              style: TextStyle(
                                color: isCheckedIn ? AppColors.primary : AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Session Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isCheckedIn
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCheckedIn
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCheckedIn ? AppColors.primary : AppColors.textMuted,
                            boxShadow: isCheckedIn
                                ? [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.6),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCheckedIn
                              ? 'INSIDE GYM • ${_formatLiveDuration(activeSession!.checkInTime)} (In: ${DateFormat('hh:mm a').format(activeSession.checkInTime)})'
                              : 'NOT CURRENTLY IN GYM',
                          style: TextStyle(
                            color: isCheckedIn ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Genuine High-Resolution QR Code Container
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 170,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'UID: ${user.id.substring(0, user.id.length > 8 ? 8 : user.id.length).toUpperCase()}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text(
                    'Scan at reception or gym turnstile to log attendance automatically',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 18),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showTurnstileScanModal(context, user.id, isCheckedIn),
                          icon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                          label: const Text(
                            'Scan Turnstile',
                            style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isCheckedIn) {
                              await ref.read(membershipNotifierProvider.notifier).checkOut(user.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checked out successfully! Rest well and see you next workout!'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            } else {
                              await ref.read(membershipNotifierProvider.notifier).checkIn(user.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Checked in successfully! Enjoy your workout!'),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );
                              }
                            }
                          },
                          icon: Icon(
                            isCheckedIn ? Icons.logout_rounded : Icons.login_rounded,
                            size: 18,
                            color: Colors.black,
                          ),
                          label: Text(
                            isCheckedIn ? 'Time-Out' : 'Time-In',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCheckedIn ? AppColors.accent : AppColors.primary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Attendance History',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${history.length} Total Visits',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (history.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'No check-in history yet. Tap Time-In above or scan your QR at the gate!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isCompleted ? AppColors.border : AppColors.primary.withValues(alpha: 0.5),
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
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isCompleted
                                  ? 'In: ${DateFormat('hh:mm a').format(item.checkInTime)} • Out: ${DateFormat('hh:mm a').format(item.checkOutTime!)} ($durationStr)'
                                  : 'In: ${DateFormat('hh:mm a').format(item.checkInTime)} • $durationStr',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
