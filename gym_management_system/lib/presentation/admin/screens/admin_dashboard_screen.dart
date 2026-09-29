import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/membership_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/facility_provider.dart';
import '../../../data/models/facility_model.dart';
import '../../../data/datasources/local/local_cache_service.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  void _showSendNoticeDialog(BuildContext context, WidgetRef ref, UserModel member, MembershipModel? membership) {
    final defaultMsg = membership != null
        ? 'Hi ${member.name}, your gym membership is scheduled to expire on ${DateFormat('MMMM dd, yyyy').format(membership.endDate)} (${membership.remainingDays} days left). Please visit the counter to renew!'
        : 'Hi ${member.name}, your gym membership subscription is expiring soon. Please visit the front desk to renew your pass!';

    final messageController = TextEditingController(text: defaultMsg);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
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
                      const Text(
                        'Send Expiration Notice',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recipient: ${member.name} (${member.email})',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: messageController,
                label: 'Notice Message to Member',
                hint: 'Type notification message...',
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Send Expiration Reminder',
                icon: Icons.send_rounded,
                onPressed: () async {
                  final text = messageController.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(ctx);
                  final success = await ref.read(adminNotifierProvider.notifier).sendExpirationNotice(
                    userId: member.id,
                    title: 'Gym Membership Expiration Notice',
                    message: text,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(success
                            ? 'Expiration reminder sent to ${member.name}!'
                            : 'Failed to send notification.'),
                        backgroundColor: success ? AppColors.primary : AppColors.error,
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

  void _showRecordPaymentDialog(BuildContext context, WidgetRef ref) {
    final adminState = ref.read(adminNotifierProvider);
    if (adminState.members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No registered members found to record payment for.')),
      );
      return;
    }

    String selectedUserId = adminState.members.first.id;
    String selectedPlan = 'VIP All-Access Pass';
    double selectedPrice = 2800.0;
    int durationDays = 30;

    final plans = [
      {'name': 'Monthly Standard', 'price': 1500.0, 'days': 30},
      {'name': 'VIP All-Access Pass', 'price': 2800.0, 'days': 30},
      {'name': 'Student Semester Pass', 'price': 3900.0, 'days': 90},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                        'Record Member Payment',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Select Member',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedUserId,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: adminState.members.map((m) {
                          return DropdownMenuItem(
                            value: m.id,
                            child: Text('${m.name} (${m.email})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedUserId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Subscription Tier',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedPlan,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        items: plans.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['name'] as String,
                            child: Text('${p['name']} - ₱${(p['price'] as double).toStringAsFixed(0)}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final chosen = plans.firstWhere((p) => p['name'] == val);
                            setModalState(() {
                              selectedPlan = val;
                              selectedPrice = chosen['price'] as double;
                              durationDays = chosen['days'] as int;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'Confirm & Activate Membership',
                    icon: Icons.check_circle_outline,
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final success = await ref.read(adminNotifierProvider.notifier).recordPayment(
                        userId: selectedUserId,
                        planName: selectedPlan,
                        amount: selectedPrice,
                        durationDays: durationDays,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Payment of ₱${selectedPrice.toStringAsFixed(0)} recorded! Subscription active.'
                                : 'Failed to record payment.'),
                            backgroundColor: success ? AppColors.primary : AppColors.error,
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
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final adminState = ref.watch(adminNotifierProvider);
    final kpi = adminState.kpi;

    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final revenueStr = currencyFormat.format(kpi?.monthlyRevenue ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin & Management Console'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Data',
            onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Sign Out',
            onPressed: () async {
              context.go(AppRoutes.welcome);
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Error banner
              if (adminState.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Connection issue: Using cached data. Tap refresh to retry.',
                          style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, color: AppColors.error, size: 18),
                        onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ],
              // Admin Overview Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.analytics_rounded, color: AppColors.accentCyan, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Admin Portal',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const Text(
                                'Live Operations & Revenue Synchronized with Database',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _AdminKpi(revenueStr, 'Total Revenue', AppColors.primary)),
                        Expanded(child: _AdminKpi('${kpi?.activeMembersCount ?? adminState.members.length}', 'Active Members', AppColors.accentCyan)),
                        Expanded(
                          child: _AdminKpi(
                            '${kpi?.todayCheckInsCount ?? 0}',
                            'Today Check-ins',
                            AppColors.accent,
                            onTap: () => context.push(AppRoutes.adminAttendance),
                          ),
                        ),
                        Expanded(child: _AdminKpi('${kpi?.retentionRate.toStringAsFixed(1) ?? '95.0'}%', 'Retention', Colors.purpleAccent)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: CustomButton(
                      text: '+ Register Member',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: () => context.push(AppRoutes.register),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      text: 'Record Payment',
                      icon: Icons.payment_rounded,
                      isOutlined: true,
                      onPressed: () => _showRecordPaymentDialog(context, ref),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.adminAttendance),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.primary),
                      label: const Text('Customer Attendance', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.adminFacilities),
                      icon: const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.accentCyan),
                      label: const Text('Facility & Inventory', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.accentCyan),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pending Cash Membership Approvals Section (Always Visible)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: adminState.pendingMemberships.isNotEmpty
                        ? AppColors.accent.withValues(alpha: 0.8)
                        : AppColors.border,
                  ),
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
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (adminState.pendingMemberships.isNotEmpty
                                          ? AppColors.accent
                                          : AppColors.textMuted)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.pending_actions_rounded,
                                  color: adminState.pendingMemberships.isNotEmpty
                                      ? AppColors.accent
                                      : AppColors.textMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Flexible(
                                child: Text(
                                  'Pending Cash Approvals',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: adminState.pendingMemberships.isNotEmpty
                                ? AppColors.accent
                                : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: adminState.pendingMemberships.isEmpty
                                ? Border.all(color: AppColors.border)
                                : null,
                          ),
                          child: adminState.isLoading && adminState.memberships.isEmpty
                              ? const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                    SizedBox(width: 5),
                                    Text(
                                      'CHECKING...',
                                      style: TextStyle(
                                        color: AppColors.accent,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  '${adminState.pendingMemberships.length} PENDING',
                                  style: TextStyle(
                                    color: adminState.pendingMemberships.isNotEmpty
                                        ? Colors.black
                                        : AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Members who requested a pass in the app must pay cash at the gym counter. Confirm cash received to activate their pass.',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    if (adminState.isLoading && adminState.memberships.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Checking database for pending cash requests...',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (adminState.pendingMemberships.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'All clear! No pending cash approvals waiting at the moment.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
                              tooltip: 'Check for Requests',
                              onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...adminState.pendingMemberships.map((pending) {
                        final matched = adminState.members.where((m) => m.id == pending.userId);
                        final member = (matched.isNotEmpty ? matched.first : null) ??
                            LocalCacheService().getUserById(pending.userId) ??
                            UserModel(
                              id: pending.userId,
                              name: 'Member (${pending.userId.length > 6 ? pending.userId.substring(0, 6) : pending.userId})',
                              email: 'Cash Payment Requested',
                              role: UserRole.member,
                              createdAt: DateTime.now(),
                            );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          member.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      '₱${pending.price.toStringAsFixed(0)} CASH',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(Icons.card_membership_rounded, size: 14, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Plan: ${pending.planName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(pending.startDate),
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final ok = await ref.read(adminNotifierProvider.notifier).approveMembership(pending);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(ok
                                                  ? 'Cash verified! ${member.name}\'s ${pending.planName} is now ACTIVE.'
                                                  : 'Failed to approve membership.'),
                                              backgroundColor: ok ? AppColors.primary : AppColors.error,
                                            ),
                                          );
                                        }
                                      },
                                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
                                      label: const Text(
                                        'Confirm Cash & Approve',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: () async {
                                      final ok = await ref.read(adminNotifierProvider.notifier).rejectMembership(
                                        membershipId: pending.id,
                                        userId: pending.userId,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(ok ? 'Membership request declined.' : 'Failed to decline.'),
                                            backgroundColor: AppColors.error,
                                          ),
                                        );
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                      minimumSize: const Size(40, 36),
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    child: const Icon(Icons.close_rounded, size: 16),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Trainer Utilization & Workload Tracker (Manuscript Figure 4.3)
              _buildTrainerUtilizationTracker(context, adminState),
              const SizedBox(height: 16),

              // Recent Activity Log Audit Trail (Manuscript Figure 4.3)
              _buildRecentActivityLog(context, adminState),
              const SizedBox(height: 16),

              // AI System Benchmarks & ISO 25010 Evaluation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Benchmarks & ISO 25010',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Model accuracy (94.2%), LP solver latency & thesis defense metrics',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => context.push(AppRoutes.aiBenchmark),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('View', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Portal Access Cross-Navigation
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.dashboard_customize_rounded, color: AppColors.accentCyan, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Portal Access & Staff Directory',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Admin privileges to inspect Member and Coach portals in real-time',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.adminMembersDirectory),
                            icon: const Icon(Icons.person_rounded, size: 16, color: AppColors.primary),
                            label: const Text('Member Records', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.adminCoachesDirectory),
                            icon: const Icon(Icons.sports_gymnastics_rounded, size: 16, color: AppColors.accent),
                            label: const Text('Coach Records', style: TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.accent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.adminAttendance),
                            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.primary),
                            label: const Text('Attendance Logs', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.push(AppRoutes.welcome),
                            icon: const Icon(Icons.public_rounded, size: 16, color: AppColors.accentCyan),
                            label: const Text('Public Landing', style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.accentCyan),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showAvailableEquipmentSheet(context, ref),
                        icon: const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Available Equipments',
                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Search & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members Directory (${adminState.members.length})',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              CustomTextField(
                hint: 'Search members by name or email...',
                prefixIcon: Icons.search,
                onChanged: (v) => ref.read(adminNotifierProvider.notifier).setSearchQuery(v),
              ),
              const SizedBox(height: 14),

              if (adminState.isLoading && adminState.members.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                ),
              ] else if (adminState.filteredMembers.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.people_outline, color: AppColors.textMuted, size: 40),
                        const SizedBox(height: 10),
                        const Text(
                          'No members found',
                          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adminState.searchQuery.isNotEmpty ? 'Try a different search query' : 'Tap "+ Register Member" to add one',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ...adminState.filteredMembers.map((m) {
                  final membership = adminState.getMembershipForUser(m.id);
                  final isPending = membership?.isPending ?? false;
                  final isActive = membership?.isActive ?? false;

                  final badgeColor = isActive
                      ? AppColors.primary
                      : (isPending ? AppColors.accent : (membership != null ? AppColors.error : AppColors.textMuted));
                  final badgeText = isActive
                      ? 'Active'
                      : (isPending ? 'Pending Cash' : (membership != null ? 'Expired' : 'No Plan'));
                  final subText = isPending
                      ? '₱${membership?.price.toStringAsFixed(0) ?? '0'} Due'
                      : (isActive
                          ? '${membership?.remainingDays ?? 0} days left'
                          : (membership != null ? 'Expired' : 'No Pass Recorded'));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPending ? AppColors.accent.withValues(alpha: 0.5) : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: badgeColor.withValues(alpha: 0.15),
                              child: Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                                style: TextStyle(
                                  color: badgeColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.name,
                                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.email} • Goal: ${m.fitnessGoal}',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    badgeText,
                                    style: TextStyle(
                                      color: badgeColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  subText,
                                  style: TextStyle(
                                    color: isPending ? AppColors.accent : AppColors.textMuted,
                                    fontSize: 11,
                                    fontWeight: isPending ? FontWeight.w700 : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isPending) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    if (membership == null) return;
                                    final ok = await ref.read(adminNotifierProvider.notifier).approveMembership(membership);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? 'Cash confirmed! ${m.name}\'s ${membership.planName} is now ACTIVE.'
                                              : 'Failed to approve membership.'),
                                          backgroundColor: ok ? AppColors.primary : AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
                                  label: Text(
                                    'Confirm Cash (${membership?.planName ?? 'Plan'})',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.event_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  membership != null
                                      ? (isPending
                                          ? 'Requested: ${DateFormat('MMM dd, yyyy').format(membership.startDate)}'
                                          : 'Expires: ${DateFormat('MMM dd, yyyy').format(membership.endDate)}')
                                      : 'No expiration date recorded',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => _showSendNoticeDialog(context, ref, m, membership),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.notifications_active_outlined, size: 14, color: AppColors.accent),
                                    SizedBox(width: 6),
                                    Text(
                                      'Send Notice',
                                      style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // ── AVAILABLE EQUIPMENTS SECTION (Bandang Ibaba ng Admin Dashboard) ──
              const SizedBox(height: 24),
              const Divider(color: AppColors.border),
              const SizedBox(height: 16),
              _buildAvailableEquipmentsBottomCard(context, ref),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailableEquipmentsBottomCard(BuildContext context, WidgetRef ref) {
    final facilityState = ref.watch(facilityNotifierProvider);
    final allEquipment = facilityState.equipment.isNotEmpty
        ? facilityState.equipment
        : LocalCacheService().getAllEquipment();
    final operationalCount = allEquipment.where((e) => e.isOperational).length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available Equipments',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$operationalCount of ${allEquipment.length} equipment operational & ready for use',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '$operationalCount READY',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: CustomButton(
                  text: 'Available Equipments',
                  icon: Icons.fitness_center_rounded,
                  onPressed: () => _showAvailableEquipmentSheet(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: CustomButton(
                  text: 'Manage',
                  icon: Icons.tune_rounded,
                  isOutlined: true,
                  onPressed: () => context.push('${AppRoutes.adminFacilities}?tab=1'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAvailableEquipmentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        String filterQuery = '';
        String selectedFilter = 'All';

        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final facilityState = ref.watch(facilityNotifierProvider);
            final allEquipment = facilityState.equipment.isNotEmpty
                ? facilityState.equipment
                : LocalCacheService().getAllEquipment();

            final operationalList = allEquipment.where((e) => e.isOperational).toList();
            final maintenanceList = allEquipment.where((e) => !e.isOperational).toList();

            final displayedList = allEquipment.where((e) {
              if (selectedFilter == 'Operational' && !e.isOperational) return false;
              if (selectedFilter == 'Maintenance' && e.isOperational) return false;
              if (filterQuery.trim().isNotEmpty) {
                final q = filterQuery.toLowerCase();
                final matchesName = e.name.toLowerCase().contains(q);
                final matchesCat = e.category.toLowerCase().contains(q);
                final matchesSerial = e.serialNumber.toLowerCase().contains(q);
                final matchesZone = e.facilityName.toLowerCase().contains(q);
                if (!matchesName && !matchesCat && !matchesSerial && !matchesZone) return false;
              }
              return true;
            }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.8,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 14,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Available Equipments',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${operationalList.length} of ${allEquipment.length} units operational & ready',
                                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        onChanged: (v) => setSheetState(() => filterQuery = v),
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search equipment by name, serial, or zone...',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.surfaceLight,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: 'All (${allEquipment.length})',
                              isSelected: selectedFilter == 'All',
                              onTap: () => setSheetState(() => selectedFilter = 'All'),
                              activeColor: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Operational (${operationalList.length})',
                              isSelected: selectedFilter == 'Operational',
                              onTap: () => setSheetState(() => selectedFilter = 'Operational'),
                              activeColor: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              label: 'Maintenance (${maintenanceList.length})',
                              isSelected: selectedFilter == 'Maintenance',
                              onTap: () => setSheetState(() => selectedFilter = 'Maintenance'),
                              activeColor: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Expanded(
                        child: displayedList.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.search_off_rounded, color: AppColors.textMuted, size: 36),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'No matching equipment found',
                                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        filterQuery.isNotEmpty ? 'Try changing your search term' : 'No items match this filter',
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: displayedList.length,
                                itemBuilder: (c, idx) {
                                  final eq = displayedList[idx];
                                  return _buildEquipmentSheetItem(eq);
                                },
                              ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: CustomButton(
                              text: 'Manage Inventory & Facilities',
                              icon: Icons.tune_rounded,
                              isOutlined: true,
                              onPressed: () {
                                Navigator.pop(ctx);
                                context.push('${AppRoutes.adminFacilities}?tab=1');
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentSheetItem(EquipmentModel eq) {
    final isOp = eq.isOperational;
    final isMaint = eq.isUnderMaintenance;
    final badgeColor = isOp
        ? AppColors.primary
        : (isMaint ? AppColors.accent : AppColors.error);
    final badgeText = isOp
        ? 'OPERATIONAL'
        : (isMaint ? 'MAINTENANCE' : 'OUT OF ORDER');

    IconData catIcon = Icons.fitness_center_rounded;
    if (eq.category.toLowerCase().contains('cardio')) {
      catIcon = Icons.directions_run_rounded;
    } else if (eq.category.toLowerCase().contains('functional')) {
      catIcon = Icons.sports_mma_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOp ? AppColors.primary.withValues(alpha: 0.25) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(catIcon, color: badgeColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eq.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${eq.facilityName} • ${eq.serialNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                color: badgeColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainerUtilizationTracker(BuildContext context, AdminState adminState) {
    final coaches = adminState.coaches.isNotEmpty
        ? adminState.coaches
        : [
            UserModel(
              id: 'coach_demo_01',
              name: 'Coach Marcus Vance',
              email: 'coach@gym.com',
              role: UserRole.coach,
              fitnessGoal: 'Strength & Conditioning',
              createdAt: DateTime.now(),
            )
          ];

    final sessions = LocalCacheService().getAllSessions();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.speed_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Trainer Workload Tracker',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'CAPACITY: 10',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Workload balancing across personal trainers against maximum capacity constraints',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...coaches.map((coach) {
            final coachSessions = sessions.where((s) => s.coachId == coach.id).length;
            final assignedCount = coachSessions > 0
                ? coachSessions
                : (adminState.members.isNotEmpty ? (adminState.members.length / coaches.length).round().clamp(1, 10) : 2);
            const maxCapacity = 10;
            final ratio = (assignedCount / maxCapacity).clamp(0.0, 1.0);
            final percent = (ratio * 100).toInt();

            final statusColor = percent >= 90
                ? AppColors.accent
                : (percent >= 50 ? AppColors.accentCyan : AppColors.primary);
            final statusText = percent >= 90
                ? 'Near Capacity'
                : (percent >= 50 ? 'Balanced' : 'Available');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: statusColor.withValues(alpha: 0.2),
                        child: Text(
                          coach.name.isNotEmpty ? coach.name[0].toUpperCase() : 'C',
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coach.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            Text(
                              coach.fitnessGoal.isNotEmpty ? coach.fitnessGoal : 'Strength & Conditioning',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$assignedCount/$maxCapacity ($percent%)',
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      backgroundColor: AppColors.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentActivityLog(BuildContext context, AdminState adminState) {
    final List<Map<String, dynamic>> activities = [];

    for (final m in adminState.members.take(3)) {
      activities.add({
        'icon': Icons.person_add_alt_1_rounded,
        'color': AppColors.accentCyan,
        'title': 'New Member Registered',
        'detail': '${m.name} joined as gym member',
        'time': m.createdAt,
      });
    }

    for (final pay in adminState.memberships.where((m) => m.isActive).take(3)) {
      final match = adminState.members.where((u) => u.id == pay.userId);
      final member = match.isNotEmpty ? match.first : null;
      activities.add({
        'icon': Icons.check_circle_outline_rounded,
        'color': AppColors.primary,
        'title': 'Membership Active',
        'detail': '${member?.name ?? "Member"} confirmed ${pay.planName} (₱${pay.price.toStringAsFixed(0)})',
        'time': pay.startDate,
      });
    }

    final attendance = LocalCacheService().getAllAttendance();
    for (final att in attendance.take(3)) {
      final match = adminState.members.where((u) => u.id == att.userId);
      final member = match.isNotEmpty ? match.first : null;
      final isOut = att.checkOutTime != null;
      activities.add({
        'icon': isOut ? Icons.logout_rounded : Icons.login_rounded,
        'color': isOut ? AppColors.accent : AppColors.primary,
        'title': isOut ? 'Member Checked Out' : 'Member Checked In',
        'detail': '${member?.name ?? "Member"} ${isOut ? "completed gym session" : "entered facility"}',
        'time': isOut ? att.checkOutTime! : att.checkInTime,
      });
    }

    activities.sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));
    final displayed = activities.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Recent Activity Log',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'LIVE AUDIT',
                  style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Running audit trail recording registrations, transactions, and check-ins',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (displayed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recent activity recorded yet.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            )
          else
            ...displayed.map((act) {
              final icon = act['icon'] as IconData;
              final color = act['color'] as Color;
              final title = act['title'] as String;
              final detail = act['detail'] as String;
              final time = act['time'] as DateTime;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            detail,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(time),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _AdminKpi extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AdminKpi(this.value, this.label, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
