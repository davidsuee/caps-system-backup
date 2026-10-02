import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_textfield.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/membership_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/admin_provider.dart';
import '../providers/facility_provider.dart';
import '../../../data/models/facility_model.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../widgets/admin_sidebar_navigation.dart';

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
      backgroundColor: context.surfaceBg,
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
                      Text(
                        'Send Expiration Notice',
                        style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.mutedColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Recipient: ${member.name} (${member.email})',
                style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600),
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


  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;
    final adminState = ref.watch(adminNotifierProvider);
    final kpi = adminState.kpi;

    final currencyFormat = NumberFormat.currency(symbol: '₱', decimalDigits: 0);
    final revenueStr = currencyFormat.format(kpi?.monthlyRevenue ?? 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;

        final mainContent = RefreshIndicator(
          onRefresh: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 28 : 16,
              vertical: isDesktop ? 24 : 16,
            ),
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
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: context.isDark ? AppColors.accentCyan.withValues(alpha: 0.4) : context.borderLine,
                  ),
                  boxShadow: context.isDark
                      ? null
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Live Operations & Revenue Synchronized with Database',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
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
              const SizedBox(height: 20),

              // Pending Cash Membership Approvals Section (Always Visible)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: adminState.pendingMemberships.isNotEmpty
                        ? AppColors.accent.withValues(alpha: 0.8)
                        : context.borderLine,
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
                                          : context.mutedColor)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.pending_actions_rounded,
                                  color: adminState.pendingMemberships.isNotEmpty
                                      ? AppColors.accent
                                      : context.mutedColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  'Pending Cash Approvals',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.titleColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            await context.push('${AppRoutes.adminPayment}?tab=1');
                            if (context.mounted) {
                              ref.read(adminNotifierProvider.notifier).loadDashboard();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: adminState.pendingMemberships.isNotEmpty
                                  ? AppColors.accent
                                  : context.elevatedSurface,
                              borderRadius: BorderRadius.circular(12),
                              border: adminState.pendingMemberships.isEmpty
                                  ? Border.all(color: context.borderLine)
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
                                        : context.mutedColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Members who requested a pass in the app must pay cash at the gym counter. Confirm cash received to activate their pass.',
                      style: TextStyle(color: context.subtitleColor, fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    if (adminState.isLoading && adminState.memberships.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Checking database for pending cash requests...',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (adminState.pendingMemberships.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'All clear! No pending cash approvals waiting at the moment.',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
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
                            color: context.elevatedSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderLine),
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
                                          style: TextStyle(
                                            color: context.titleColor,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          member.email,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: context.subtitleColor,
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
                                  Icon(Icons.card_membership_rounded, size: 14, color: context.mutedColor),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Plan: ${pending.planName}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.titleColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd, yyyy').format(pending.startDate),
                                    style: TextStyle(color: context.mutedColor, fontSize: 11),
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

              const SizedBox(height: 24),

              // Search & Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Members Directory (${adminState.members.length})',
                    style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
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
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, color: context.mutedColor, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'No members found',
                          style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          adminState.searchQuery.isNotEmpty ? 'Try a different search query' : 'Tap "+ Register Member" to add one',
                          style: TextStyle(color: context.subtitleColor, fontSize: 12),
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
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isPending ? AppColors.accent.withValues(alpha: 0.5) : context.borderLine,
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
                                    style: TextStyle(color: context.titleColor, fontSize: 15, fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${m.email} • Goal: ${m.fitnessGoal}',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
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
                                    color: isPending ? AppColors.accent : context.mutedColor,
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
                        Divider(color: context.borderLine, height: 1),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.event_outlined, size: 14, color: context.subtitleColor),
                                const SizedBox(width: 6),
                                Text(
                                  membership != null
                                      ? (isPending
                                          ? 'Requested: ${DateFormat('MMM dd, yyyy').format(membership.startDate)}'
                                          : 'Expires: ${DateFormat('MMM dd, yyyy').format(membership.endDate)}')
                                      : 'No expiration date recorded',
                                  style: TextStyle(color: context.subtitleColor, fontSize: 12),
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

              const SizedBox(height: 24),
              // Recent Activity Log (Live audit trail)
              _buildRecentActivityLog(context, adminState),
              const SizedBox(height: 32),
            ],
          ),
        );

        if (isDesktop) {
          return Scaffold(
            backgroundColor: context.bg,
            body: Row(
              children: [
                AdminSidebarNavigation(
                  currentRoute: AppRoutes.adminDashboard,
                  onAvailableEquipmentsTap: () => _showAvailableEquipmentSheet(context, ref),
                ),
                Expanded(
                  child: Column(
                    children: [
                      _buildDesktopHeader(context, ref),
                      Expanded(child: mainContent),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: context.bg,
          drawer: AdminSidebarNavigation(
            isDrawer: true,
            currentRoute: AppRoutes.adminDashboard,
            onAvailableEquipmentsTap: () {
              Navigator.of(context).pop();
              _showAvailableEquipmentSheet(context, ref);
            },
          ),
          appBar: AppBar(
            backgroundColor: context.surfaceBg,
            elevation: 1,
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Navigation Menu',
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
            title: const Text(
              'Admin & Management Console',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            actions: [
              const ThemeToggleButton(),
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
          body: SafeArea(child: mainContent),
        );
      },
    );
  }

  Widget _buildDesktopHeader(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: context.surfaceBg,
        border: Border(
          bottom: BorderSide(color: context.borderLine, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.dashboard_customize_rounded, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin & Management Console',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Enterprise Operations • Live Synchronized System',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: context.subtitleColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Live Sync Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_rounded, color: AppColors.primary, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'CLOUD SYNCED',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const ThemeToggleButton(),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh Dashboard',
                onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
              ),
              const SizedBox(width: 6),
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
        ],
      ),
    );
  }

  void _showAvailableEquipmentSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceBg,
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
                            color: context.borderLine,
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
                                  Text(
                                    'Available Equipments',
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${operationalList.length} of ${allEquipment.length} units operational & ready',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: context.mutedColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      TextField(
                        onChanged: (v) => setSheetState(() => filterQuery = v),
                        style: TextStyle(color: context.titleColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search equipment by name, serial, or zone...',
                          hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.mutedColor),
                          filled: true,
                          fillColor: context.elevatedSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.borderLine),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.borderLine),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              context,
                              label: 'All (${allEquipment.length})',
                              isSelected: selectedFilter == 'All',
                              onTap: () => setSheetState(() => selectedFilter = 'All'),
                              activeColor: context.titleColor,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context,
                              label: 'Operational (${operationalList.length})',
                              isSelected: selectedFilter == 'Operational',
                              onTap: () => setSheetState(() => selectedFilter = 'Operational'),
                              activeColor: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            _buildFilterChip(
                              context,
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
                                      Icon(Icons.search_off_rounded, color: context.mutedColor, size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No matching equipment found',
                                        style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        filterQuery.isNotEmpty ? 'Try changing your search term' : 'No items match this filter',
                                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
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
                                  return _buildEquipmentSheetItem(context, eq);
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

  Widget _buildFilterChip(
    BuildContext context, {
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
          color: isSelected ? activeColor.withValues(alpha: 0.15) : context.elevatedSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : context.borderLine,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : context.subtitleColor,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildEquipmentSheetItem(BuildContext context, EquipmentModel eq) {
    final isOccupied = eq.isOccupied;
    final isOp = eq.isOperational;
    final isMaint = eq.isUnderMaintenance;
    final badgeColor = isOccupied
        ? AppColors.warning
        : (isOp
            ? AppColors.primary
            : (isMaint ? AppColors.accent : AppColors.error));
    final badgeText = isOccupied
        ? 'OCCUPIED (IN USE)'
        : (isOp
            ? 'OPERATIONAL'
            : (isMaint ? 'MAINTENANCE' : 'OUT OF ORDER'));

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
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOp ? AppColors.primary.withValues(alpha: 0.25) : context.borderLine,
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
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${eq.facilityName} • ${eq.serialNumber}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
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
    return _TrainerWorkloadTrackerSection(adminState: adminState);
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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderLine),
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
                    Expanded(
                      child: Text(
                        'Recent Activity Log',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.titleColor,
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
          Text(
            'Running audit trail recording registrations, transactions, and check-ins',
            style: TextStyle(color: context.subtitleColor, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (displayed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No recent activity recorded yet.',
                style: TextStyle(color: context.mutedColor, fontSize: 12),
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
                  color: context.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderLine),
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
                            style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            detail,
                            style: TextStyle(color: context.subtitleColor, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      DateFormat('hh:mm a').format(time),
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
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
              style: TextStyle(color: context.subtitleColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerWorkloadTrackerSection extends StatefulWidget {
  final AdminState adminState;

  const _TrainerWorkloadTrackerSection({required this.adminState});

  @override
  State<_TrainerWorkloadTrackerSection> createState() => _TrainerWorkloadTrackerSectionState();
}

class _TrainerWorkloadTrackerSectionState extends State<_TrainerWorkloadTrackerSection> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coaches = widget.adminState.coaches.isNotEmpty
        ? widget.adminState.coaches
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

    final allMembers = widget.adminState.members;
    final totalAssignedCount = allMembers.where((m) =>
        m.assignedCoachId != null && m.assignedCoachId!.isNotEmpty
    ).length;

    final query = _searchQuery.trim().toLowerCase();

    // Check if any coach has matching clients when query is not empty
    int totalMatches = 0;
    if (query.isNotEmpty) {
      for (final coach in coaches) {
        final assigned = allMembers.where((m) =>
            m.assignedCoachId != null &&
            m.assignedCoachId!.isNotEmpty &&
            m.assignedCoachId == coach.id
        );
        totalMatches += assigned.where((m) =>
            m.name.toLowerCase().contains(query) ||
            m.fitnessGoal.toLowerCase().contains(query) ||
            m.email.toLowerCase().contains(query)
        ).length;
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.borderLine),
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
                      child: const Icon(Icons.people_outline_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Trainer Workload Tracker',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => context.push(AppRoutes.adminCoachesDirectory),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$totalAssignedCount ASSIGNED',
                        style: TextStyle(color: context.subtitleColor, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios_rounded, size: 9, color: context.mutedColor),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Assigned clients roster per coach — tap any coach to drop down their client list or search by name',
            style: TextStyle(color: context.subtitleColor, fontSize: 12),
          ),
          const SizedBox(height: 14),

          // Search bar to find clients without endless scrolling
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderLine),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: context.titleColor, fontSize: 13),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                hintText: 'Search client name or fitness goal...',
                hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                prefixIcon: Icon(Icons.search_rounded, color: context.mutedColor, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: context.mutedColor, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 14),

          if (query.isNotEmpty && totalMatches == 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderLine),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.person_search_rounded, color: context.mutedColor, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      'No assigned clients found matching "$_searchQuery"',
                      style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Try searching with a different name or clear the search filter',
                      style: TextStyle(color: context.mutedColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          else
            ...coaches.map((coach) {
              final assignedMembers = allMembers.where((m) =>
                  m.assignedCoachId != null &&
                  m.assignedCoachId!.isNotEmpty &&
                  m.assignedCoachId == coach.id
              ).toList();

              return _CoachWorkloadCard(
                key: ValueKey('${coach.id}_$query'),
                coach: coach,
                assignedMembers: assignedMembers,
                searchQuery: query,
                initialExpanded: false, // Default is collapsed! Admin decides to drop down
              );
            }),
        ],
      ),
    );
  }
}

class _CoachWorkloadCard extends StatefulWidget {
  final UserModel coach;
  final List<UserModel> assignedMembers;
  final bool initialExpanded;
  final String searchQuery;

  const _CoachWorkloadCard({
    super.key,
    required this.coach,
    required this.assignedMembers,
    this.initialExpanded = false,
    this.searchQuery = '',
  });

  @override
  State<_CoachWorkloadCard> createState() => _CoachWorkloadCardState();
}

class _CoachWorkloadCardState extends State<_CoachWorkloadCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    // If a search query is active and this coach has matches, auto-expand to show search results
    if (widget.searchQuery.isNotEmpty) {
      _isExpanded = true;
    } else {
      _isExpanded = widget.initialExpanded; // defaults to false
    }
  }

  @override
  Widget build(BuildContext context) {
    final coach = widget.coach;
    final allAssigned = widget.assignedMembers;
    final query = widget.searchQuery.trim().toLowerCase();

    // Filter assigned members by search query if present
    final displayedMembers = query.isEmpty
        ? allAssigned
        : allAssigned.where((m) =>
            m.name.toLowerCase().contains(query) ||
            m.fitnessGoal.toLowerCase().contains(query) ||
            m.email.toLowerCase().contains(query)
          ).toList();

    // If searching and this coach has 0 matching clients, hide this coach card
    if (query.isNotEmpty && displayedMembers.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (query.isNotEmpty && displayedMembers.isNotEmpty)
              ? AppColors.primary.withValues(alpha: 0.5)
              : context.borderLine,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Coach row (clickable to drop down or collapse)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      coach.name.isNotEmpty ? coach.name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coach.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.titleColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          coach.specialization != null && coach.specialization!.isNotEmpty
                              ? coach.specialization!
                              : (coach.fitnessGoal.isNotEmpty ? coach.fitnessGoal : 'General Training'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: context.subtitleColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: displayedMembers.isNotEmpty
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : context.borderLine.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: displayedMembers.isNotEmpty
                            ? AppColors.primary.withValues(alpha: 0.35)
                            : context.borderLine,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: displayedMembers.isNotEmpty ? AppColors.primary : context.mutedColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          query.isNotEmpty
                              ? '${displayedMembers.length} Matched'
                              : '${allAssigned.length} ${allAssigned.length == 1 ? 'Client' : 'Clients'}',
                          style: TextStyle(
                            color: displayedMembers.isNotEmpty ? AppColors.primary : context.mutedColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: context.mutedColor,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Client list section (shown only when dropped down)
          if (_isExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Divider(height: 1, color: context.borderLine.withValues(alpha: 0.7)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: displayedMembers.isEmpty
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.borderLine.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 16, color: context.mutedColor),
                          const SizedBox(width: 8),
                          Text(
                            'No clients currently assigned to this coach.',
                            style: TextStyle(color: context.subtitleColor, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, left: 2),
                          child: Text(
                            query.isNotEmpty
                                ? 'MATCHING CLIENTS (${displayedMembers.length})'
                                : 'ASSIGNED CLIENTS (${allAssigned.length})',
                            style: TextStyle(
                              color: context.mutedColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        ...displayedMembers.map((member) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: context.cardColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: context.borderLine.withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 13,
                                    backgroundColor: AppColors.accentCyan.withValues(alpha: 0.15),
                                    child: Text(
                                      member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                                      style: const TextStyle(
                                        color: AppColors.accentCyan,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          member.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: context.titleColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          member.fitnessGoal.isNotEmpty
                                              ? 'Goal: ${member.fitnessGoal}'
                                              : (member.email.isNotEmpty ? member.email : 'Member'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: context.subtitleColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (member.gender.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: context.elevatedSurface,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: context.borderLine.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(
                                        member.gender,
                                        style: TextStyle(
                                          color: context.mutedColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
