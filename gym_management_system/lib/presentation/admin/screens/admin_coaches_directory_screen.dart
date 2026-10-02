import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/entities/trainer_assignment_entity.dart';
import '../providers/admin_provider.dart';
import '../widgets/add_coach_dialog.dart';

class AdminCoachesDirectoryScreen extends ConsumerStatefulWidget {
  const AdminCoachesDirectoryScreen({super.key});

  @override
  ConsumerState<AdminCoachesDirectoryScreen> createState() =>
      _AdminCoachesDirectoryScreenState();
}

class _AdminCoachesDirectoryScreenState
    extends ConsumerState<AdminCoachesDirectoryScreen> {
  String _searchQuery = '';
  bool _isOptimizing = false;

  Future<void> _handleRunOptimization() async {
    setState(() => _isOptimizing = true);
    try {
      final result = await ref
          .read(adminNotifierProvider.notifier)
          .runAutoAssignmentOptimization();
      if (mounted) {
        setState(() => _isOptimizing = false);
        if (result != null) {
          _showOptimizationResultSheet(context, result);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not complete optimization. Check available coaches.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isOptimizing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Optimization error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showOptimizationResultSheet(
      BuildContext context, AssignmentOptimizationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
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
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: context.mutedColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Assignment Optimization Complete',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Constraint-based workload & synergy matching',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Metrics summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricItem(
                        label: 'Evaluated',
                        value: '${result.totalEvaluated}',
                        color: context.titleColor,
                      ),
                      Container(width: 1, height: 32, color: context.borderLine),
                      _buildMetricItem(
                        label: 'Matches Formed',
                        value: '${result.newlyAssignedCount}',
                        color: AppColors.primary,
                      ),
                      Container(width: 1, height: 32, color: context.borderLine),
                      _buildMetricItem(
                        label: 'Synergy Avg',
                        value: result.matches.isEmpty
                            ? '100%'
                            : '${(result.matches.fold(0, (sum, m) => sum + m.matchScore) / result.matches.length).round()}%',
                        color: AppColors.accentCyan,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Allocated Pairings & Compatibility Details',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),

                if (result.matches.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'All members are currently optimally assigned to coaches!',
                        style: TextStyle(color: context.subtitleColor, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...result.matches.map((m) => _buildMatchCard(m)),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Done & View Updated Roster',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMetricItem({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchCard(AssignmentMatch m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.memberName,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Goal: ${m.memberGoal}',
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: context.mutedColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      m.coachName,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.coachSpecialization,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.borderLine),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${m.matchScore}% Match',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    m.matchReason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isDayPassMember(String userId, AdminState adminState) {
    final mem = adminState.getMembershipForUser(userId);
    if (mem != null) {
      final name = mem.planName.toLowerCase();
      return name.contains('day') || name.contains('walk');
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminNotifierProvider);
    final allCoaches = adminState.coaches;
    final allMembers = adminState.members;

    final unassignedCount = allMembers
        .where((m) =>
            !_isDayPassMember(m.id, adminState) &&
            (m.assignedCoachId == null || m.assignedCoachId!.isEmpty))
        .length;

    final q = _searchQuery.trim().toLowerCase();
    final filteredCoaches = q.isEmpty
        ? allCoaches
        : allCoaches
            .where((c) =>
                c.name.toLowerCase().contains(q) ||
                c.email.toLowerCase().contains(q) ||
                (c.specialization ?? '').toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.titleColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Coaches Directory',
          style: TextStyle(
            color: context.titleColor,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ElevatedButton.icon(
              onPressed: () => showAddCoachDialog(context, ref),
              icon: const Icon(Icons.person_add_rounded, size: 15),
              label: const Text(
                'Add Coach',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const ThemeToggleButton(),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sports_gymnastics_rounded,
                    color: AppColors.accent, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${allCoaches.length}',
                  style: const TextStyle(
                    color: AppColors.accent,
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
          // Optimization Banner (Objective 4 & DFD 6.0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  context.cardColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trainer Assignment Engine',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Workload balancing & goal-specialization synergy',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: unassignedCount > 0
                            ? AppColors.warning.withValues(alpha: 0.15)
                            : AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        unassignedCount > 0
                            ? '$unassignedCount Unassigned Members'
                            : 'All Members Allocated',
                        style: TextStyle(
                          color: unassignedCount > 0
                              ? AppColors.warning
                              : AppColors.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      height: 36,
                      child: ElevatedButton.icon(
                        onPressed: _isOptimizing ? null : _handleRunOptimization,
                        icon: _isOptimizing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(
                          _isOptimizing ? 'Optimizing...' : '⚡ Run Auto-Assign',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: context.cardColor,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(color: context.titleColor, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name, email, or specialization...',
                hintStyle:
                    TextStyle(color: context.mutedColor, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, color: context.mutedColor, size: 20),
                filled: true,
                fillColor: context.elevatedSurface,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.borderLine),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.accent, width: 1.5),
                ),
              ),
            ),
          ),

          // Coach list
          Expanded(
            child: adminState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : filteredCoaches.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.sports_gymnastics_rounded,
                                color:
                                    context.mutedColor.withValues(alpha: 0.5),
                                size: 56),
                            const SizedBox(height: 12),
                            Text(
                              'No coaches found',
                              style: TextStyle(
                                color: context.titleColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try a different search query'
                                  : 'No registered coaches yet',
                              style: TextStyle(
                                color: context.subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredCoaches.length,
                        itemBuilder: (context, index) {
                          final coach = filteredCoaches[index];
                          final assigned = allMembers
                              .where((m) => m.assignedCoachId == coach.id && !_isDayPassMember(m.id, adminState))
                              .toList();
                          return _CoachRecordCard(
                            coach: coach,
                            assignedMembers: assigned,
                            onTap: () =>
                                _showCoachDetailSheet(context, coach, assigned),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddCoachDialog(context, ref),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          'Add Coach',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showCoachDetailSheet(
      BuildContext context, UserModel coach, List<UserModel> assigned) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
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
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: context.mutedColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Profile header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                      child: Text(
                        coach.name.isNotEmpty ? coach.name[0].toUpperCase() : 'C',
                        style: const TextStyle(
                          color: AppColors.accent,
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
                            coach.name,
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            coach.email,
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              coach.specialization ?? 'Strength & Conditioning',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Active Clients summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Clients',
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${assigned.length} ${assigned.length == 1 ? "Client" : "Clients"}',
                            style: TextStyle(
                              color: context.titleColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Assigned Members Roster Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Assigned Clients (${assigned.length})',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showManualAssignPicker(context, coach);
                      },
                      icon: const Icon(Icons.person_add_rounded, size: 14, color: AppColors.primary),
                      label: const Text('Add Client',
                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (assigned.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'No clients currently assigned to this coach.',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...assigned.map((member) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              child: Text(
                                member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : 'M',
                                style: const TextStyle(
                                  color: AppColors.primary,
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
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    'Goal: ${member.fitnessGoal}',
                                    style: TextStyle(
                                      color: context.mutedColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded,
                                  color: AppColors.textMuted, size: 18),
                              tooltip: 'Unassign client',
                              onPressed: () async {
                                final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
                                final ok = await ref
                                    .read(adminNotifierProvider.notifier)
                                    .manuallyAssignCoach(
                                      memberId: member.id,
                                      coachId: '',
                                    );
                                if (ctx.mounted) Navigator.pop(ctx);
                                scaffoldMessenger?.showSnackBar(
                                  SnackBar(
                                    content: Text(ok
                                        ? 'Unassigned ${member.name} from ${coach.name}.'
                                        : 'Failed to unassign client.'),
                                    backgroundColor:
                                        ok ? AppColors.primary : AppColors.error,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      )),

                const SizedBox(height: 20),

                // Personal Info Section
                _DetailSection(
                  title: 'Personal Information',
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.accent,
                  children: [
                    _DetailRow('Full Name', coach.name),
                    _DetailRow('Email', coach.email),
                    _DetailRow('Gender', coach.gender),
                    _DetailRow('Age', '${coach.age} years old'),
                    _DetailRow('Experience', coach.experienceLevel),
                  ],
                ),
                const SizedBox(height: 24),

                // Remove Coach button (Allowed for any coach, unassigning their members)
                OutlinedButton.icon(
                  onPressed: () => _confirmRemoveCoach(coach),
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 16),
                  label: const Text(
                    'Remove Coach from Gym',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  void _confirmRemoveCoach(UserModel coach) {
    final rootContext = context;
    showDialog(
      context: rootContext,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: rootContext.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Remove ${coach.name}?',
                style: TextStyle(
                  color: rootContext.titleColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${coach.name} from the gym coaching staff? Any members currently assigned to this coach will be unassigned.',
          style: TextStyle(color: rootContext.subtitleColor, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Cancel', style: TextStyle(color: rootContext.mutedColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(dlgCtx);
              Navigator.pop(rootContext);
              final success = await ref.read(adminNotifierProvider.notifier).removeCoach(coach.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? '${coach.name} removed from gym coaching roster.'
                        : 'Could not remove coach.',
                  ),
                  backgroundColor: success ? AppColors.primary : AppColors.error,
                ),
              );
            },
            child: const Text('Remove Coach'),
          ),
        ],
      ),
    );
  }

  void _showManualAssignPicker(BuildContext context, UserModel coach) {
    final adminState = ref.read(adminNotifierProvider);
    final allMembers = adminState.members;
    final unassignedOrOther = allMembers
        .where((m) => m.assignedCoachId != coach.id && !_isDayPassMember(m.id, adminState))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
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
                  'Assign Client to ${coach.name}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Select a member to manually allocate to this coach roster',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (unassignedOrOther.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'All gym members are already assigned to this coach.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...unassignedOrOther.map((member) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            member.name.isNotEmpty
                                ? member.name[0].toUpperCase()
                                : 'M',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          member.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          'Goal: ${member.fitnessGoal}',
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final ok = await ref
                                .read(adminNotifierProvider.notifier)
                                .manuallyAssignCoach(
                                  memberId: member.id,
                                  coachId: coach.id,
                                );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(ok
                                      ? 'Assigned ${member.name} to ${coach.name}!'
                                      : 'Failed to assign coach.'),
                                  backgroundColor:
                                      ok ? AppColors.primary : AppColors.error,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Assign', style: TextStyle(fontSize: 12)),
                        ),
                      )),
              ],
            );
          },
        );
      },
    );
  }
}

// --- Supporting Widgets ---

class _CoachRecordCard extends StatelessWidget {
  final UserModel coach;
  final List<UserModel> assignedMembers;
  final VoidCallback onTap;

  const _CoachRecordCard({
    required this.coach,
    required this.assignedMembers,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assignedCount = assignedMembers.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.borderLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                  child: Text(
                    coach.name.isNotEmpty ? coach.name[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: AppColors.accent,
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
                        coach.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        coach.email,
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Coach',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Specialization badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.fitness_center_rounded,
                      size: 13, color: AppColors.accentCyan),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      coach.specialization ?? 'Strength & Conditioning',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Clients Count Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Assigned Clients',
                  style: TextStyle(
                    color: context.mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        '$assignedCount ${assignedCount == 1 ? "Client" : "Clients"}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Assigned Member Chips
            if (assignedMembers.isNotEmpty) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: assignedMembers.take(20).map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      m.name,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
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
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.borderLine),
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
                style: TextStyle(
                  color: context.titleColor,
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
