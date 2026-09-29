import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/membership_model.dart';
import '../../../domain/entities/membership_entity.dart';
import '../providers/admin_provider.dart';

class AdminMembersDirectoryScreen extends ConsumerStatefulWidget {
  const AdminMembersDirectoryScreen({super.key});

  @override
  ConsumerState<AdminMembersDirectoryScreen> createState() =>
      _AdminMembersDirectoryScreenState();
}

enum MemberFilterTab { all, pendingCash, active, noPlan }

class _AdminMembersDirectoryScreenState
    extends ConsumerState<AdminMembersDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  MemberFilterTab _activeFilter = MemberFilterTab.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminNotifierProvider);
    final allMembers = adminState.members;
    final memberships = adminState.memberships;

    final pendingCount = allMembers.where((m) => _getMembership(m.id, memberships)?.isPending == true).length;
    final activeCount = allMembers.where((m) => _getMembership(m.id, memberships)?.isActive == true).length;

    final q = _searchQuery.trim().toLowerCase();
    final filteredMembers = allMembers.where((m) {
      if (q.isNotEmpty) {
        final matchesQuery = m.name.toLowerCase().contains(q) ||
            m.email.toLowerCase().contains(q) ||
            m.fitnessGoal.toLowerCase().contains(q) ||
            m.experienceLevel.toLowerCase().contains(q);
        if (!matchesQuery) return false;
        // When searching by name or email, don't let the tab filter hide the searched member!
        return true;
      }
      final mem = _getMembership(m.id, memberships);
      switch (_activeFilter) {
        case MemberFilterTab.all:
          return true;
        case MemberFilterTab.pendingCash:
          return mem?.isPending == true;
        case MemberFilterTab.active:
          return mem?.isActive == true;
        case MemberFilterTab.noPlan:
          return mem == null || mem.isExpired;
      }
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Members Records',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh Members',
            onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_rounded, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${allMembers.length}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search members by name or email...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // Filter chips row
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChipTab(
                    label: 'All (${allMembers.length})',
                    isSelected: _activeFilter == MemberFilterTab.all,
                    onTap: () => setState(() => _activeFilter = MemberFilterTab.all),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipTab(
                    label: 'Pending Cash ($pendingCount)',
                    isSelected: _activeFilter == MemberFilterTab.pendingCash,
                    badgeColor: pendingCount > 0 ? AppColors.accent : null,
                    onTap: () => setState(() => _activeFilter = MemberFilterTab.pendingCash),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipTab(
                    label: 'Active ($activeCount)',
                    isSelected: _activeFilter == MemberFilterTab.active,
                    onTap: () => setState(() => _activeFilter = MemberFilterTab.active),
                  ),
                  const SizedBox(width: 8),
                  _FilterChipTab(
                    label: 'No Plan / Expired',
                    isSelected: _activeFilter == MemberFilterTab.noPlan,
                    onTap: () => setState(() => _activeFilter = MemberFilterTab.noPlan),
                  ),
                ],
              ),
            ),
          ),
          const Divider(color: AppColors.border, height: 1),

          // Member list
          Expanded(
            child: adminState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : filteredMembers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_rounded,
                                color: AppColors.textMuted.withValues(alpha: 0.5), size: 56),
                            const SizedBox(height: 12),
                            Text(
                              _activeFilter == MemberFilterTab.pendingCash
                                  ? 'No pending cash approvals'
                                  : 'No members found',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search query'
                                  : (_activeFilter == MemberFilterTab.pendingCash
                                      ? 'Any customer requesting a cash pass will show here'
                                      : 'No members match the selected filter'),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredMembers.length,
                        itemBuilder: (context, index) {
                          final member = filteredMembers[index];
                          final membership = _getMembership(member.id, memberships);
                          return _MemberRecordCard(
                            member: member,
                            membership: membership,
                            onTap: () => _showMemberDetailSheet(context, member, membership),
                            onApprovePending: membership?.isPending == true
                                ? () async {
                                    if (membership == null) return;
                                    final ok = await ref.read(adminNotifierProvider.notifier).approveMembership(membership);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(ok
                                              ? 'Cash confirmed! ${member.name}\'s ${membership.planName} is active.'
                                              : 'Failed to approve membership.'),
                                          backgroundColor: ok ? AppColors.primary : AppColors.error,
                                        ),
                                      );
                                    }
                                  }
                                : null,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  MembershipModel? _getMembership(String userId, List<MembershipModel> memberships) {
    try {
      final userMems = memberships.where((m) => m.userId == userId).toList();
      if (userMems.isEmpty) return null;
      // Active membership always takes highest priority!
      final active = userMems.where((m) => m.status == MembershipStatus.active && m.isActive).firstOrNull;
      if (active != null) return active;
      final pending = userMems.where((m) => m.status == MembershipStatus.pending).firstOrNull;
      if (pending != null) return pending;
      return userMems.first;
    } catch (_) {
      return null;
    }
  }

  void _showMemberDetailSheet(
      BuildContext context, UserModel member, MembershipModel? membership) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            final isActive = membership?.isActive ?? false;
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // Header
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Profile header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.email,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(builder: (context) {
                      final isPending = membership?.isPending ?? false;
                      final badgeColor = isActive
                          ? AppColors.primary
                          : (isPending ? AppColors.accent : AppColors.error);
                      final badgeText = isActive
                          ? 'Active'
                          : (isPending ? 'Pending Cash' : (membership != null ? 'Expired' : 'No Plan'));

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 24),

                // Membership Info Section
                _DetailSection(
                  title: 'Membership Information',
                  icon: Icons.card_membership_rounded,
                  iconColor: AppColors.accentCyan,
                  children: [
                    _DetailRow('Plan', membership?.planName ?? 'No active plan'),
                    _DetailRow('Price',
                        membership != null ? '₱${membership.price.toStringAsFixed(0)}' : '—'),
                    _DetailRow(
                        'Start Date',
                        membership != null
                            ? DateFormat('MMM dd, yyyy').format(membership.startDate)
                            : '—'),
                    _DetailRow(
                        'Expiry Date',
                        membership != null
                            ? DateFormat('MMM dd, yyyy').format(membership.endDate)
                            : '—'),
                    _DetailRow(
                        'Days Remaining',
                        membership != null
                            ? '${membership.remainingDays} days'
                            : '—'),
                    _DetailRow('Status', membership != null
                        ? (isActive ? 'Active' : (membership.isPending ? 'Pending Cash Payment' : 'Expired'))
                        : 'No membership'),
                  ],
                ),
                if (membership?.isPending == true) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (membership == null) return;
                      Navigator.pop(ctx);
                      final ok = await ref.read(adminNotifierProvider.notifier).approveMembership(membership);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Payment verified! ${member.name}\'s ${membership.planName} is active.'
                                : 'Failed to approve membership.'),
                            backgroundColor: ok ? AppColors.primary : AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.black, size: 18),
                    label: Text('Confirm Cash & Activate (${membership?.planName ?? 'Plan'})',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Assigned Coach Section (Objective 4 & DFD 6.0)
                Builder(builder: (context) {
                  final coaches = ref.watch(adminNotifierProvider).coaches;
                  final coach = coaches.where((c) => c.id == member.assignedCoachId).firstOrNull;

                  return _DetailSection(
                    title: 'Assigned Fitness Coach',
                    icon: Icons.sports_gymnastics_rounded,
                    iconColor: AppColors.accent,
                    children: [
                      _DetailRow('Trainer', coach?.name ?? 'Not assigned yet'),
                      if (coach?.specialization != null)
                        _DetailRow('Specialization', coach!.specialization!),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _showCoachPickerForMember(context, member, coaches);
                          },
                          icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                          label: Text(coach != null ? 'Reassign Coach' : 'Assign Coach'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 16),

                // Personal Info Section
                _DetailSection(
                  title: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primary,
                  children: [
                    _DetailRow('Gender', member.gender),
                    _DetailRow('Age', '${member.age} years old'),
                    _DetailRow('Height', '${member.heightCm.toStringAsFixed(1)} cm'),
                    _DetailRow('Weight', '${member.weightKg.toStringAsFixed(1)} kg'),
                    _DetailRow('BMI', member.bmi.toStringAsFixed(1)),
                  ],
                ),
                const SizedBox(height: 16),

                // Fitness Profile Section
                _DetailSection(
                  title: 'Fitness Profile',
                  icon: Icons.fitness_center_rounded,
                  iconColor: AppColors.accent,
                  children: [
                    _DetailRow('Fitness Goal', member.fitnessGoal),
                    _DetailRow('Activity Level', member.activityLevel),
                    _DetailRow('Experience Level', member.experienceLevel),
                    _DetailRow(
                        'Dietary Restrictions',
                        member.dietaryRestrictions.isNotEmpty
                            ? member.dietaryRestrictions.join(', ')
                            : 'None'),
                    _DetailRow(
                        'Available Equipment',
                        member.availableEquipment.isNotEmpty
                            ? member.availableEquipment.join(', ')
                            : 'None'),
                    _DetailRow(
                        'Injuries / Flags',
                        member.injuryFlags.isNotEmpty
                            ? member.injuryFlags.join(', ')
                            : 'None reported'),
                  ],
                ),
                const SizedBox(height: 16),

                // Account Info Section
                _DetailSection(
                  title: 'Account Information',
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.purpleAccent,
                  children: [
                    _DetailRow('Member ID', member.id.length > 12
                        ? '${member.id.substring(0, 12)}...'
                        : member.id),
                    _DetailRow('Registered On',
                        DateFormat('MMM dd, yyyy').format(member.createdAt)),
                    _DetailRow('Role', member.role.displayName),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  void _showCoachPickerForMember(
      BuildContext context, UserModel member, List<UserModel> coaches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.textMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Assign Coach for ${member.name}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Member Goal: ${member.fitnessGoal}',
                  style: const TextStyle(
                    color: AppColors.accentCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                if (coaches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No coaches registered in system.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...coaches.map((c) {
                    final isCurrent = c.id == member.assignedCoachId;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCurrent ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          c.specialization ?? 'Strength & Conditioning',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: isCurrent
                              ? null
                              : () async {
                                  final ok = await ref
                                      .read(adminNotifierProvider.notifier)
                                      .manuallyAssignCoach(
                                        memberId: member.id,
                                        coachId: c.id,
                                      );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Assigned ${member.name} to ${c.name}!'
                                            : 'Failed to assign coach.'),
                                        backgroundColor:
                                            ok ? AppColors.primary : AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isCurrent ? AppColors.border : AppColors.primary,
                            foregroundColor: isCurrent ? AppColors.textMuted : Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(isCurrent ? 'Current' : 'Select'),
                        ),
                      ),
                    );
                  }),
              ],
            );
          },
        );
      },
    );
  }
}

class _FilterChipTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? badgeColor;
  final VoidCallback onTap;

  const _FilterChipTab({
    required this.label,
    required this.isSelected,
    this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = badgeColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? AppColors.primary)
              : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (color ?? AppColors.primary)
                : (color != null ? color.withValues(alpha: 0.5) : AppColors.border),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : (badgeColor ?? AppColors.textPrimary),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _MemberRecordCard extends StatelessWidget {
  final UserModel member;
  final MembershipModel? membership;
  final VoidCallback onTap;
  final VoidCallback? onApprovePending;

  const _MemberRecordCard({
    required this.member,
    required this.membership,
    required this.onTap,
    this.onApprovePending,
  });

  @override
  Widget build(BuildContext context) {
    final isPending = membership?.isPending ?? false;
    final isActive = membership?.isActive ?? false;
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                  radius: 22,
                  backgroundColor:
                      (isActive ? AppColors.primary : (isPending ? AppColors.accent : AppColors.error))
                          .withValues(alpha: 0.15),
                  child: Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                    style: TextStyle(
                      color: isActive ? AppColors.primary : (isPending ? AppColors.accent : AppColors.error),
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
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
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
                Builder(builder: (context) {
                  final mem = membership;
                  final badgeColor = isActive
                      ? AppColors.primary
                      : (isPending ? AppColors.accent : (mem != null ? AppColors.error : AppColors.textMuted));
                  final badgeText = isActive
                      ? 'Active'
                      : (isPending ? 'Pending Cash' : (mem != null ? 'Expired' : 'No Plan'));

                  return Column(
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
                        mem != null
                            ? (isPending
                                ? '₱${mem.price.toStringAsFixed(0)} Due'
                                : (isActive ? '${mem.remainingDays} days left' : 'Expired'))
                            : 'No pass recorded',
                        style: TextStyle(
                          color: isPending ? AppColors.accent : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: isPending ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ],
            ),
            if (isPending && onApprovePending != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onApprovePending,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.black),
                  label: Text(
                    'Confirm Cash Received & Activate (${membership?.planName ?? 'Plan'})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 10),
            // Quick info row
            Row(
              children: [
                Flexible(child: _QuickInfoChip(Icons.flag_rounded, member.fitnessGoal, AppColors.primary)),
                const SizedBox(width: 8),
                _QuickInfoChip(Icons.monitor_weight_outlined,
                    '${member.weightKg.toStringAsFixed(0)} kg', AppColors.accentCyan),
                const SizedBox(width: 8),
                _QuickInfoChip(Icons.straighten_rounded,
                    '${member.heightCm.toStringAsFixed(0)} cm', AppColors.accent),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _QuickInfoChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
