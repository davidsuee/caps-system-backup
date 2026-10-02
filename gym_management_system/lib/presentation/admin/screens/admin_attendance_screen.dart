import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../data/models/membership_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/walk_in_record_model.dart';
import '../providers/admin_provider.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const AdminAttendanceScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _registryKey = GlobalKey();

  String? _selectedUserId;
  String _memberSearchQuery = '';
  String _registrySearchQuery = '';
  Timer? _liveSyncTimer;
  Timer? _durationTickerTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    Future.microtask(() {
      if (mounted) {
        ref.read(adminNotifierProvider.notifier).loadDashboard();
      }
    });

    // Auto-sync dashboard every 4 seconds for real-time cloud data
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        ref.read(adminNotifierProvider.notifier).loadDashboard();
      }
    });

    // Live second-by-second ticker for active workout durations, current time, and auto-checkout at 11:00 PM
    _durationTickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final autoClosed = LocalCacheService().autoCheckOutClosedSessions();
        if (autoClosed) {
          ref.read(adminNotifierProvider.notifier).loadDashboard();
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _durationTickerTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _scrollToRegistry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_registryKey.currentContext != null) {
        Scrollable.ensureVisible(
          _registryKey.currentContext!,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      } else if (_scrollController.hasClients) {
        _scrollController.animateTo(
          480,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  /// Gym Operating Hours: 8:00 AM – 11:00 PM Daily (08:00 - 23:00)
  bool _isGymOpen([DateTime? time]) {
    final t = time ?? DateTime.now();
    return t.hour >= 8 && t.hour < 23;
  }

  String _formatLiveDuration(DateTime checkInTime, [DateTime? checkOutTime]) {
    final closingTime = DateTime(checkInTime.year, checkInTime.month, checkInTime.day, 23, 0);
    final now = DateTime.now();
    final effectiveEnd = checkOutTime ?? (now.isAfter(closingTime) ? closingTime : now);
    final diff = effectiveEnd.difference(checkInTime);
    if (diff.isNegative) return '00m 00s';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    final secs = diff.inSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
    }
    return '${mins.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
  }

  UserModel? _findMember(String userId, List<UserModel> members) {
    for (final m in members) {
      if (m.id == userId) return m;
    }
    return LocalCacheService().getUserById(userId);
  }

  MembershipModel? _getMembershipForUser(String userId, AdminState adminState) {
    final mem = adminState.getMembershipForUser(userId);
    if (mem != null) return mem;
    return LocalCacheService().getMembership(userId);
  }

  Future<void> _handleCheckInAttempt(UserModel member) async {
    final now = DateTime.now();
    final isOpen = _isGymOpen(now);

    if (!isOpen) {
      // Gym is closed: Strictly block check-in. No override permitted outside 8:00 AM - 11:00 PM.
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: context.cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_clock_rounded, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Facility Closed: Check-In Disabled',
                  style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vicious Fitness operating hours are 8:00 AM to 11:00 PM Daily.\n\nCurrent Time: ${DateFormat('hh:mm a').format(now)} (Facility Closed)',
                style: TextStyle(color: context.subtitleColor, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.elevatedSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderLine),
                ),
                child: Text(
                  'Member check-in is strictly disabled outside operating hours (before 8:00 AM and after 11:00 PM) to ensure facility compliance and attendance integrity.\n\nAll active workout sessions automatically check out at 11:00 PM.',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Understood', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
          ],
        ),
      );
      return;
    }

    // Proceed with check in
    final ok = await ref.read(adminNotifierProvider.notifier).checkInMember(member.id);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✓ TIME-IN RECORDED: Welcome ${member.name}! Enjoy your workout.'
              : ref.read(adminNotifierProvider).errorMessage ?? 'Check-in failed.'),
          backgroundColor: ok ? AppColors.primary : AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminNotifierProvider);
    final members = adminState.members;
    final rawAttendance = adminState.attendance.isNotEmpty
        ? adminState.attendance
        : LocalCacheService().getAllAttendance();

    final now = DateTime.now();
    final isFacilityOpen = _isGymOpen(now);

    final allAttendance = rawAttendance.map((a) {
      if (a.checkOutTime == null) {
        final closingTime = DateTime(
          a.checkInTime.year,
          a.checkInTime.month,
          a.checkInTime.day,
          23,
          0,
        );
        if (now.isAfter(closingTime) || now.isAtSameMomentAs(closingTime) || a.checkInTime.isAfter(closingTime)) {
          final outTime = a.checkInTime.isAfter(closingTime) ? a.checkInTime : closingTime;
          return AttendanceModel(
            id: a.id,
            userId: a.userId,
            checkInTime: a.checkInTime,
            checkOutTime: outTime,
            guestName: a.guestName,
            isWalkIn: a.isWalkIn,
            amountPaid: a.amountPaid,
            contactNumber: a.contactNumber,
            paymentMethod: a.paymentMethod,
            notes: a.notes,
          );
        }
      }
      return a;
    }).toList();

    final allWalkIns = adminState.walkIns.isNotEmpty
        ? adminState.walkIns
        : LocalCacheService().getAllWalkInRecords();

    // Default select first member if nothing selected
    if (_selectedUserId == null && members.isNotEmpty) {
      _selectedUserId = members.first.id;
    }

    final todayLogs = allAttendance.where((a) {
      return a.checkInTime.year == now.year &&
          a.checkInTime.month == now.month &&
          a.checkInTime.day == now.day;
    }).toList();

    // Active workout sessions: strictly 0 if gym is closed, and only unclosed sessions from today before 11 PM
    final activeSessions = isFacilityOpen
        ? allAttendance.where((a) {
            if (a.checkOutTime != null) return false;
            final closingTime = DateTime(a.checkInTime.year, a.checkInTime.month, a.checkInTime.day, 23, 0);
            if (now.isAfter(closingTime) || now.isAtSameMomentAs(closingTime)) return false;
            return true;
          }).toList()
        : <AttendanceModel>[];

    // Find active attendance for selected member
    AttendanceModel? selectedUserActive;
    if (_selectedUserId != null && isFacilityOpen) {
      for (final a in activeSessions) {
        if (a.userId == _selectedUserId) {
          selectedUserActive = a;
          break;
        }
      }
      if (selectedUserActive == null) {
        final localActive = LocalCacheService().getActiveAttendance(_selectedUserId!);
        if (localActive != null && localActive.checkOutTime == null) {
          final closingTime = DateTime(
            localActive.checkInTime.year,
            localActive.checkInTime.month,
            localActive.checkInTime.day,
            23,
            0,
          );
          if (now.isBefore(closingTime)) {
            selectedUserActive = localActive;
          }
        }
      }
    }

    final selectedMember = _selectedUserId != null ? _findMember(_selectedUserId!, members) : null;
    final selectedMembership = _selectedUserId != null ? _getMembershipForUser(_selectedUserId!, adminState) : null;

    return Scaffold(
      backgroundColor: context.bg,
      appBar: AppBar(
        backgroundColor: context.cardColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.borderLine),
            ),
            child: Icon(Icons.arrow_back_rounded, color: context.titleColor, size: 18),
          ),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Front Desk Attendance Console',
                  style: TextStyle(
                    color: context.titleColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isFacilityOpen ? AppColors.primary : AppColors.error).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isFacilityOpen ? AppColors.primary : AppColors.error).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    isFacilityOpen ? 'OPEN (8 AM - 11 PM)' : 'CLOSED NOW',
                    style: TextStyle(
                      color: isFacilityOpen ? AppColors.primary : AppColors.error,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Search Member Name & 1-Click Instant Attendance',
              style: TextStyle(color: context.mutedColor, fontSize: 11),
            ),
          ],
        ),
        actions: [
          const ThemeToggleButton(),
          // Quick Walk-In Button directly in AppBar
          ElevatedButton.icon(
            onPressed: () => _showLogWalkInDialog(context),
            icon: const Icon(Icons.directions_walk_rounded, size: 14, color: Colors.black),
            label: const Text(
              '+ Walk-In',
              style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 6),
          // Live Occupancy Pill Badge (Accurate Real-Time Count without Limit)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${activeSessions.length} In Gym',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
            tooltip: 'Sync Data',
            onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
          ),
          const SizedBox(width: 6),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border(bottom: BorderSide(color: context.borderLine, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              onTap: (index) {
                setState(() {});
                _scrollToRegistry();
              },
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.fitness_center_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text('Inside Gym Now (${activeSessions.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.today_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text("Today's Activity (${todayLogs.length})"),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text('All Logs (${allAttendance.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.directions_walk_rounded, size: 15),
                      const SizedBox(width: 6),
                      Text('Walk-Ins (${allWalkIns.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // OPERATING HOURS NOTIFICATION BANNER (IF CLOSED)
          if (!isFacilityOpen) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FACILITY CLOSED: Outside Operating Hours',
                          style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Operating Hours are 8:00 AM – 11:00 PM Daily. Time-in is locked until 8:00 AM (Admin Override required).',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 1. STAR CONSOLE: RAPID FRONT DESK ATTENDANCE TERMINAL
          _buildFrontDeskConsole(
            context,
            members: members,
            selectedMember: selectedMember,
            selectedMembership: selectedMembership,
            selectedUserActive: selectedUserActive,
            isFacilityOpen: isFacilityOpen,
          ),
          const SizedBox(height: 18),

          // 2. LIVE FACILITY CAPACITY & KPI GAUGES
          _buildFacilityMetrics(activeSessions, todayLogs, allAttendance),
          const SizedBox(height: 20),

          // 3. REGISTRY FILTER & AUDIT LIST HEADER
          KeyedSubtree(
            key: _registryKey,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.list_alt_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Live Attendance Registry — ${_tabController.index == 0 ? "Inside Gym" : _tabController.index == 1 ? "Today's Activity" : _tabController.index == 2 ? "All Logs" : "Walk-Ins / Day Pass"}',
                      style: TextStyle(
                        color: context.titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 220,
                  height: 38,
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderLine),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextField(
                    onChanged: (v) => setState(() => _registrySearchQuery = v.trim().toLowerCase()),
                    style: TextStyle(color: context.titleColor, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Filter list by member...',
                      hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                      icon: Icon(Icons.filter_list_rounded, color: context.mutedColor, size: 16),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Direct Segmented Tab Pills right above the table
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderLine),
            ),
            child: Row(
              children: [
                _buildRegistryTabPill(
                  title: 'Inside (${activeSessions.length})',
                  icon: Icons.fitness_center_rounded,
                  index: 0,
                ),
                const SizedBox(width: 4),
                _buildRegistryTabPill(
                  title: "Today (${todayLogs.length})",
                  icon: Icons.today_rounded,
                  index: 1,
                ),
                const SizedBox(width: 4),
                _buildRegistryTabPill(
                  title: 'All Logs (${allAttendance.length})',
                  icon: Icons.history_rounded,
                  index: 2,
                ),
                const SizedBox(width: 4),
                _buildRegistryTabPill(
                  title: 'Walk-Ins (${allWalkIns.length})',
                  icon: Icons.directions_walk_rounded,
                  index: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. TAB CONTENT: REAL-TIME ATTENDANCE LOGS
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInsideGymTab(activeSessions, members),
                _buildAttendanceList(todayLogs, members, emptyMsg: 'No members logged in today yet.'),
                _buildAttendanceList(allAttendance, members, emptyMsg: 'No attendance records found.'),
                _buildWalkInsTab(allWalkIns),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // =========================================================================
  // 1. FRONT DESK CONSOLE (OPTION A: INSTANT SEARCH & 1-CLICK ATTENDANCE)
  // =========================================================================
  Widget _buildFrontDeskConsole(
    BuildContext context, {
    required List<UserModel> members,
    required UserModel? selectedMember,
    required MembershipModel? selectedMembership,
    required AttendanceModel? selectedUserActive,
    required bool isFacilityOpen,
  }) {
    final isInside = selectedUserActive != null;
    final isMembershipValid = selectedMembership?.isValid ?? false;
    final isMembershipExpired = selectedMembership?.isExpired ?? false;

    // Filter members for live autocomplete dropdown
    final matchingMembers = _memberSearchQuery.isEmpty
        ? <UserModel>[]
        : members.where((m) {
            final q = _memberSearchQuery.toLowerCase();
            return m.name.toLowerCase().contains(q) ||
                m.email.toLowerCase().contains(q) ||
                m.id.toLowerCase().contains(q);
          }).take(4).toList();

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isInside
              ? AppColors.accent.withValues(alpha: 0.6)
              : AppColors.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isInside ? AppColors.accent : AppColors.primary).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Console Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isInside
                            ? [AppColors.accent.withValues(alpha: 0.25), AppColors.accent.withValues(alpha: 0.08)]
                            : [AppColors.primary.withValues(alpha: 0.25), AppColors.primary.withValues(alpha: 0.08)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isInside ? Icons.storefront_rounded : Icons.person_search_rounded,
                      color: isInside ? AppColors.accent : AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Front Desk Rapid Check-In Terminal',
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        isInside
                            ? 'Member is currently training inside • 1-Click to Time-Out'
                            : 'Search customer name or ID • 1-Click to Time-In',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isInside ? AppColors.accent.withValues(alpha: 0.15) : AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isInside ? '● OCCUPIED SESSION' : '● READY FOR ENTRY',
                  style: TextStyle(
                    color: isInside ? AppColors.accent : AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // SEARCH INPUT FIELD WITH INSTANT FILTERING
          Container(
            decoration: BoxDecoration(
              color: context.elevatedSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _memberSearchQuery.isNotEmpty ? AppColors.primary : context.borderLine,
                width: _memberSearchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w600),
              onChanged: (val) {
                setState(() {
                  _memberSearchQuery = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Type customer name, email, or ID (e.g. Dave, Maria)...',
                hintStyle: TextStyle(color: context.mutedColor, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                suffixIcon: _memberSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close_rounded, color: context.mutedColor, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _memberSearchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
          ),

          // WALK-IN QUICK TIME-IN COUNTER ACTION (NO ACCOUNT NEEDED)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.directions_walk_rounded, color: Colors.amber, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Walk-In Customer (No Account Needed)',
                        style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Day Pass Guest • Direct counter time-in without online registration',
                        style: TextStyle(color: context.subtitleColor, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showLogWalkInDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 16, color: Colors.black),
                  label: const Text('Log Walk-In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // AUTOCOMPLETE DROPDOWN RESULTS (IF SEARCHING)
          if (matchingMembers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(color: context.isDark ? Colors.black26 : Colors.black12, blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matchingMembers.length,
                separatorBuilder: (_, __) => Divider(color: context.borderLine, height: 1),
                itemBuilder: (ctx, index) {
                  final m = matchingMembers[index];
                  final inGym = LocalCacheService().getActiveAttendance(m.id) != null;
                  final mem = _getMembershipForUser(m.id, ref.read(adminNotifierProvider));

                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: (inGym ? AppColors.accent : AppColors.primary).withValues(alpha: 0.2),
                      child: Text(
                        m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                        style: TextStyle(
                          color: inGym ? AppColors.accent : AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    title: Text(
                      m.name,
                      style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${m.email} • ${mem?.planName ?? 'No Plan'}',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (inGym)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'INSIDE',
                              style: TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'OUTSIDE',
                              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios_rounded, color: context.mutedColor, size: 12),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _selectedUserId = m.id;
                        _memberSearchQuery = '';
                        _searchController.text = m.name;
                      });
                      _searchFocusNode.unfocus();
                    },
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 14),

          // QUICK-SELECT MEMBER CAROUSEL (IF NOT SEARCHING)
          if (_memberSearchQuery.isEmpty && members.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Select Member (Recent Walk-ins):',
                  style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${members.length} Total Members',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: members.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, idx) {
                  final m = members[idx];
                  final isSelected = m.id == _selectedUserId;
                  final inGym = LocalCacheService().getActiveAttendance(m.id) != null;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedUserId = m.id;
                        _searchController.text = m.name;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (inGym ? AppColors.accent : AppColors.primary).withValues(alpha: 0.2)
                            : context.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? (inGym ? AppColors.accent : AppColors.primary)
                              : context.borderLine,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: (inGym ? AppColors.accent : AppColors.primary).withValues(alpha: 0.25),
                            child: Text(
                              m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                              style: TextStyle(
                                color: inGym ? AppColors.accent : AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            m.name.split(' ').first,
                            style: TextStyle(
                              color: isSelected ? context.titleColor : context.subtitleColor,
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                          if (inGym) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SELECTED MEMBER VIP SPOTLIGHT CARD
          if (selectedMember != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isInside ? AppColors.accent.withValues(alpha: 0.5) : context.borderLine,
                ),
              ),
              child: Column(
                children: [
                  // Member Identity Row
                  Row(
                    children: [
                      // Big Avatar with Glow
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isInside ? AppColors.accent : AppColors.primary).withValues(alpha: 0.15),
                          border: Border.all(
                            color: isInside ? AppColors.accent : AppColors.primary,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            selectedMember.name.isNotEmpty ? selectedMember.name[0].toUpperCase() : 'M',
                            style: TextStyle(
                              color: isInside ? AppColors.accent : AppColors.primary,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    selectedMember.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: context.titleColor,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.elevatedSurface,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ID: VIC-${selectedMember.id.length > 5 ? selectedMember.id.substring(0, 5).toUpperCase() : selectedMember.id}',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 10, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              selectedMember.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: context.mutedColor, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Membership & Gym Presence Status Row
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Membership Badge
                        Row(
                          children: [
                            Icon(
                              isMembershipValid
                                  ? Icons.verified_rounded
                                  : isMembershipExpired
                                      ? Icons.warning_amber_rounded
                                      : Icons.card_membership_rounded,
                              size: 16,
                              color: isMembershipValid
                                  ? AppColors.primary
                                  : isMembershipExpired
                                      ? AppColors.error
                                      : AppColors.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMembershipValid
                                      ? 'ACTIVE MEMBERSHIP'
                                      : isMembershipExpired
                                          ? 'EXPIRED PLAN'
                                          : 'REGISTERED GUEST',
                                  style: TextStyle(
                                    color: isMembershipValid
                                        ? AppColors.primary
                                        : isMembershipExpired
                                            ? AppColors.error
                                            : AppColors.accentCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  selectedMembership != null
                                      ? '${selectedMembership.planName} (${selectedMembership.remainingDays}d left)'
                                      : 'Standard Access',
                                  style: TextStyle(color: context.subtitleColor, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Presence State
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: (isInside ? AppColors.accent : context.cardColor),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isInside ? Colors.transparent : context.borderLine),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isInside ? Colors.black : context.mutedColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isInside ? 'INSIDE GYM' : 'OUTSIDE',
                                style: TextStyle(
                                  color: isInside ? Colors.black : context.subtitleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Active Session Timer (if inside)
                  if (isInside) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.timer_outlined, color: AppColors.accent, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Checked In at ${DateFormat('hh:mm a').format(selectedUserActive.checkInTime)}',
                                style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          Text(
                            'Active: ${_formatLiveDuration(selectedUserActive.checkInTime)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // MASSIVE 1-CLICK TACTILE ACTION BUTTONS
                  if (!isInside) ...[
                    // TIME-IN (CHECK-IN) BUTTON - RESPECTS OPERATING HOURS
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleCheckInAttempt(selectedMember),
                        icon: Icon(
                          isFacilityOpen ? Icons.login_rounded : Icons.lock_clock_rounded,
                          size: 22,
                          color: isFacilityOpen ? Colors.black : Colors.white70,
                        ),
                        label: Text(
                          isFacilityOpen
                              ? 'LOG TIME-IN (TIME: ${DateFormat('hh:mm a').format(DateTime.now())})'
                              : 'FACILITY CLOSED • OPENS 8:00 AM',
                          style: TextStyle(
                            color: isFacilityOpen ? Colors.black : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFacilityOpen ? AppColors.primary : AppColors.error.withValues(alpha: 0.8),
                          elevation: 6,
                          shadowColor: (isFacilityOpen ? AppColors.primary : AppColors.error).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ] else ...[
                    // TIME-OUT (CHECK-OUT) BUTTON - ALWAYS PERMITTED EVEN AFTER CLOSING
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final ok = await ref.read(adminNotifierProvider.notifier).checkOutMember(selectedMember.id);
                          setState(() {});
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✓ TIME-OUT RECORDED: Goodbye ${selectedMember.name}! Session completed.'),
                                backgroundColor: ok ? AppColors.accent : AppColors.error,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 22, color: Colors.black),
                        label: const Text(
                          'LOG TIME-OUT (COMPLETE WORKOUT SESSION)',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          elevation: 6,
                          shadowColor: AppColors.accent.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            // Empty State Prompt
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderLine),
              ),
              child: Column(
                children: [
                  Icon(Icons.touch_app_rounded, color: context.mutedColor, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'No Member Selected',
                    style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Type member name above or tap an avatar to log attendance instantly.',
                    style: TextStyle(color: context.subtitleColor, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegistryTabPill({
    required String title,
    required IconData icon,
    required int index,
  }) {
    final isSelected = _tabController.index == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          _tabController.animateTo(index);
          setState(() {});
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.black : context.subtitleColor,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.black : context.subtitleColor,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 2. FACILITY METRICS & LIVE CAPACITY GAUGES
  // =========================================================================
  Widget _buildFacilityMetrics(
    List<AttendanceModel> activeSessions,
    List<AttendanceModel> todayLogs,
    List<AttendanceModel> allAttendance,
  ) {
    final occupancy = activeSessions.length;

    // Calculate average workout duration of completed sessions today
    final completedToday = todayLogs.where((a) => a.checkOutTime != null).toList();
    int avgMins = 45;
    if (completedToday.isNotEmpty) {
      final totalSecs = completedToday.fold<int>(
        0,
        (sum, a) => sum + a.checkOutTime!.difference(a.checkInTime).inSeconds,
      );
      avgMins = (totalSecs / completedToday.length / 60).round();
      if (avgMins < 5) avgMins = 45;
    }

    return Row(
      children: [
        // Occupancy Gauge Card
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.people_alt_rounded, color: AppColors.primary, size: 14),
                        const SizedBox(width: 4),
                        Text('Currently Inside', style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Live Counter',
                        style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '$occupancy',
                      style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Members In Gym',
                      style: TextStyle(color: context.mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Real-time active workout sessions',
                      style: TextStyle(color: context.mutedColor, fontSize: 10, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Today's Visits
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.login_rounded, color: AppColors.accentCyan, size: 14),
                    const SizedBox(width: 4),
                    Text("Today's Visits", style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${todayLogs.length}',
                  style: const TextStyle(color: AppColors.accentCyan, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entries Logged',
                  style: TextStyle(color: context.mutedColor, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Avg Duration
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.borderLine),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.accent, size: 14),
                    const SizedBox(width: 4),
                    Text('Avg Session', style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${avgMins}m',
                  style: const TextStyle(color: AppColors.accent, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Per Member',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 3. TAB 1: INSIDE GYM NOW (ACTIVE SESSIONS WITH DIRECT 1-CLICK CHECKOUT)
  // =========================================================================
  Widget _buildInsideGymTab(List<AttendanceModel> activeSessions, List<UserModel> members) {
    final filtered = activeSessions.where((a) {
      if (_registrySearchQuery.isEmpty) return true;
      if (a.isWalkIn == true) {
        final gName = (a.guestName ?? 'Walk-In Guest').toLowerCase();
        final contact = (a.contactNumber ?? '').toLowerCase();
        return gName.contains(_registrySearchQuery) || contact.contains(_registrySearchQuery);
      }
      final m = _findMember(a.userId, members);
      if (m == null) return false;
      return m.name.toLowerCase().contains(_registrySearchQuery) ||
          m.email.toLowerCase().contains(_registrySearchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center_rounded, color: context.mutedColor, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              'No Members Inside Right Now',
              style: TextStyle(color: context.titleColor, fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Use the Front Desk terminal above to log member entry.',
              style: TextStyle(color: context.subtitleColor, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, idx) {
        final item = filtered[idx];
        final isWalkIn = item.isWalkIn;
        final member = isWalkIn ? null : _findMember(item.userId, members);
        final displayName = isWalkIn ? (item.guestName ?? 'Walk-In Guest') : (member?.name ?? 'Member (${item.userId})');
        final liveDuration = _formatLiveDuration(item.checkInTime);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isWalkIn
                  ? Colors.amber.withValues(alpha: 0.6)
                  : AppColors.accent.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: (isWalkIn ? Colors.amber : AppColors.accent).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Glowing Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: (isWalkIn ? Colors.amber : AppColors.accent).withValues(alpha: 0.2),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'W',
                  style: TextStyle(
                    color: isWalkIn ? Colors.amber : AppColors.accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Member Details & Live Workout Timer
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isWalkIn)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                            ),
                            child: Text(
                              'WALK-IN • ₱${item.amountPaid?.toInt() ?? 150}',
                              style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'TRAINING',
                              style: TextStyle(color: AppColors.accent, fontSize: 9, fontWeight: FontWeight.w900),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'In: ${DateFormat('hh:mm a').format(item.checkInTime)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        ),
                        if (isWalkIn && item.paymentMethod != null) ...[
                          const SizedBox(width: 6),
                          const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          const SizedBox(width: 6),
                          Text(
                            item.paymentMethod!,
                            style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(width: 8),
                        const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                        const SizedBox(width: 8),
                        Icon(Icons.timer_outlined, size: 12, color: isWalkIn ? Colors.amber : AppColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          liveDuration,
                          style: TextStyle(
                            color: isWalkIn ? Colors.amber : AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // DIRECT 1-CLICK CHECK-OUT BUTTON ON THE ROW
              ElevatedButton.icon(
                onPressed: () async {
                  if (isWalkIn) {
                    await ref.read(adminNotifierProvider.notifier).checkOutWalkIn(item.userId);
                  } else {
                    await ref.read(adminNotifierProvider.notifier).checkOutMember(item.userId);
                  }
                  setState(() {});
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✓ TIME-OUT RECORDED: $displayName checked out! Total: $liveDuration'),
                        backgroundColor: isWalkIn ? Colors.amber : AppColors.accent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.black),
                label: const Text(
                  'Check-Out',
                  style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isWalkIn ? Colors.amber : AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 4. TAB 2 & 3: GENERAL ATTENDANCE AUDIT LOGS
  // =========================================================================
  Widget _buildAttendanceList(
    List<AttendanceModel> list,
    List<UserModel> members, {
    required String emptyMsg,
  }) {
    final filtered = list.where((a) {
      if (_registrySearchQuery.isEmpty) return true;
      if (a.isWalkIn == true) {
        final gName = (a.guestName ?? 'Walk-In Guest').toLowerCase();
        final contact = (a.contactNumber ?? '').toLowerCase();
        return gName.contains(_registrySearchQuery) || contact.contains(_registrySearchQuery);
      }
      final member = _findMember(a.userId, members);
      if (member == null) return false;
      return member.name.toLowerCase().contains(_registrySearchQuery) ||
          member.email.toLowerCase().contains(_registrySearchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, color: AppColors.textMuted, size: 36),
            const SizedBox(height: 8),
            Text(
              _registrySearchQuery.isNotEmpty ? 'No logs match "$_registrySearchQuery"' : emptyMsg,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, idx) {
        final item = filtered[idx];
        final isWalkIn = item.isWalkIn;
        final member = isWalkIn ? null : _findMember(item.userId, members);
        final displayName = isWalkIn ? (item.guestName ?? 'Walk-In Guest') : (member?.name ?? 'Customer (${item.userId})');
        final isOut = item.checkOutTime != null;

        final durationStr = isOut
            ? _formatLiveDuration(item.checkInTime, item.checkOutTime)
            : 'Active (${_formatLiveDuration(item.checkInTime)})';

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isWalkIn
                  ? Colors.amber.withValues(alpha: isOut ? 0.35 : 0.6)
                  : (isOut ? context.borderLine : AppColors.primary.withValues(alpha: 0.4)),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (isWalkIn ? Colors.amber : (isOut ? context.elevatedSurface : AppColors.primary)).withValues(alpha: 0.2),
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
                  style: TextStyle(
                    color: isWalkIn ? Colors.amber : (isOut ? context.titleColor : AppColors.primary),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (isWalkIn) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'WALK-IN • ₱${item.amountPaid?.toInt() ?? 150}',
                              style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'In: ${DateFormat('hh:mm a, MMM dd').format(item.checkInTime)}',
                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                    ),
                    if (isOut)
                      Text(
                        'Out: ${DateFormat('hh:mm a').format(item.checkOutTime!)} • Session: $durationStr',
                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                      )
                    else
                      Text(
                        'Status: Currently In Gym • $durationStr',
                        style: TextStyle(color: isWalkIn ? Colors.amber : AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isOut)
                ElevatedButton(
                  onPressed: () async {
                    if (isWalkIn) {
                      await ref.read(adminNotifierProvider.notifier).checkOutWalkIn(item.userId);
                    } else {
                      await ref.read(adminNotifierProvider.notifier).checkOutMember(item.userId);
                    }
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isWalkIn ? Colors.amber : AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text(
                    'Check-Out',
                    style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(color: context.subtitleColor, fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 5. TAB 4: WALK-INS / DAY PASS REGISTRY & REVENUE
  // =========================================================================
  Widget _buildWalkInsTab(List<WalkInRecordModel> walkIns) {
    final now = DateTime.now();
    final todayWalkIns = walkIns.where((w) {
      return w.checkInTime.year == now.year &&
          w.checkInTime.month == now.month &&
          w.checkInTime.day == now.day;
    }).toList();

    final activeWalkIns = walkIns.where((w) => w.isActive).toList();
    final totalRevenueToday = todayWalkIns.fold<double>(0, (sum, w) => sum + w.amountPaid);

    final filtered = walkIns.where((w) {
      if (_registrySearchQuery.isEmpty) return true;
      final q = _registrySearchQuery.toLowerCase();
      return w.guestName.toLowerCase().contains(q) ||
          (w.contactNumber?.toLowerCase().contains(q) ?? false) ||
          w.paymentMethod.toLowerCase().contains(q) ||
          (w.notes?.toLowerCase().contains(q) ?? false);
    }).toList();

    return Column(
      children: [
        // Summary KPI Banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.directions_walk_rounded, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Walk-In Day Passes",
                        style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${todayWalkIns.length} Passes Sold • ₱${totalRevenueToday.toStringAsFixed(0)} Revenue • ${activeWalkIns.length} Active Inside',
                        style: TextStyle(color: context.subtitleColor, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showLogWalkInDialog(context),
                icon: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
                label: const Text('Log Walk-In', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.directions_walk_rounded, color: Colors.amber, size: 36),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _registrySearchQuery.isNotEmpty ? 'No walk-ins match "$_registrySearchQuery"' : 'No Walk-In Day Passes Recorded',
                        style: TextStyle(color: context.titleColor, fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Walk-in guests are registered directly at the front counter. No online account needed.',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () => _showLogWalkInDialog(context),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: Colors.black),
                        label: const Text('Log First Walk-In Pass', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final item = filtered[idx];
                    final isActive = item.isActive;
                    final liveDuration = _formatLiveDuration(item.checkInTime, item.checkOutTime);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? Colors.amber.withValues(alpha: 0.6) : context.borderLine,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.amber.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.amber.withValues(alpha: 0.2),
                            child: Text(
                              item.guestName.isNotEmpty ? item.guestName[0].toUpperCase() : 'W',
                              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.guestName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '₱${item.amountPaid.toInt()} • ${item.paymentMethod}',
                                        style: const TextStyle(color: Colors.amber, fontSize: 9, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    if (isActive) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'INSIDE',
                                          style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w900),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'In: ${DateFormat('hh:mm a, MMM dd').format(item.checkInTime)}',
                                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('•', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                                    const SizedBox(width: 8),
                                    Text(
                                      isActive ? 'Live: $liveDuration' : 'Session: $liveDuration',
                                      style: TextStyle(
                                        color: isActive ? Colors.amber : context.mutedColor,
                                        fontSize: 11,
                                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                        fontFamily: isActive ? 'monospace' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.contactNumber != null && item.contactNumber!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Contact: ${item.contactNumber!}${item.notes != null && item.notes!.isNotEmpty ? " • Notes: ${item.notes}" : ""}',
                                    style: TextStyle(color: context.mutedColor, fontSize: 10),
                                  ),
                                ] else if (item.notes != null && item.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Notes: ${item.notes}',
                                    style: TextStyle(color: context.mutedColor, fontSize: 10),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (isActive)
                            ElevatedButton.icon(
                              onPressed: () async {
                                await ref.read(adminNotifierProvider.notifier).checkOutWalkIn(item.id);
                                setState(() {});
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('✓ TIME-OUT RECORDED: ${item.guestName} checked out!'),
                                      backgroundColor: Colors.amber,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.logout_rounded, size: 14, color: Colors.black),
                              label: const Text('Check-Out', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.amber,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: context.elevatedSurface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: context.borderLine),
                              ),
                              child: Text(
                                'Completed',
                                style: TextStyle(color: context.mutedColor, fontSize: 10, fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // =========================================================================
  // 6. WALK-IN LOG MODAL DIALOG
  // =========================================================================
  Future<void> _showLogWalkInDialog([BuildContext? _]) async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '80');
    final notesCtrl = TextEditingController();
    String selectedMethod = 'Cash';
    final isFacilityOpen = _isGymOpen();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: context.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_walk_rounded, color: Colors.amber, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Log Walk-In Day Pass',
                          style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Front Desk Direct Entry • No Account Needed',
                          style: TextStyle(color: context.subtitleColor, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isFacilityOpen) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Operating Hours are 6:00 AM – 11:00 PM. Facility is currently closed.',
                                  style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Guest Name
                      Text('Guest Full Name *', style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nameCtrl,
                        style: TextStyle(color: context.titleColor, fontSize: 13),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter guest name';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'e.g. Juan dela Cruz',
                          hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                          prefixIcon: const Icon(Icons.person_rounded, size: 18, color: Colors.amber),
                          filled: true,
                          fillColor: context.elevatedSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Contact Number
                      Text('Contact Number (Optional)', style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: context.titleColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. 09171234567',
                          hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                          prefixIcon: Icon(Icons.phone_rounded, size: 18, color: context.mutedColor),
                          filled: true,
                          fillColor: context.elevatedSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Row with Amount and Payment Method
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Day Pass Fee (₱)', style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: amountCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w800),
                                  decoration: InputDecoration(
                                    prefixText: '₱ ',
                                    prefixStyle: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w800),
                                    filled: true,
                                    fillColor: context.elevatedSurface,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Payment', style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: context.elevatedSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: context.borderLine),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.payments_rounded, size: 16, color: AppColors.primary),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Cash at Counter',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notes / Locker
                      Text('Locker / Counter Notes (Optional)', style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: notesCtrl,
                        style: TextStyle(color: context.titleColor, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'e.g. Locker #08, ID deposited',
                          hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                          prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: context.mutedColor),
                          filled: true,
                          fillColor: context.elevatedSurface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: context.borderLine)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.amber)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancel', style: TextStyle(color: context.mutedColor)),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final name = nameCtrl.text.trim();
                      final phone = phoneCtrl.text.trim();
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 150.0;
                      final notes = notesCtrl.text.trim();

                      Navigator.of(ctx).pop();

                      await ref.read(adminNotifierProvider.notifier).logWalkIn(
                        guestName: name,
                        contactNumber: phone.isEmpty ? null : phone,
                        amountPaid: amount,
                        paymentMethod: selectedMethod,
                        notes: notes.isEmpty ? null : notes,
                      );

                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ TIME-IN RECORDED: Welcome $name! Walk-In Day Pass (₱${amount.toInt()}) logged.'),
                            backgroundColor: Colors.amber,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.black),
                  label: const Text('Confirm & Time-In', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // =========================================================================
  // OPTIONAL BARCODE / MANUAL INPUT MODAL (SECONDARY TOOL)
  // =========================================================================
  // ignore: unused_element
  void _showAdminQrScannerModal(BuildContext context, List<UserModel> members) {
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.borderLine,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.barcode_reader, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Manual UID / Barcode Input',
                                style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Enter member UID or select a detected member below',
                                style: TextStyle(color: context.subtitleColor, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Manual Text Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: context.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderLine),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.badge_rounded, color: context.mutedColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: textCtrl,
                              style: TextStyle(color: context.titleColor, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Paste Member UID or ID...',
                                hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                            onPressed: () async {
                              final text = textCtrl.text.trim();
                              if (text.isEmpty) return;
                              UserModel? matched;
                              for (final m in members) {
                                if (text.contains(m.id) || m.id == text || text.toLowerCase().contains(m.name.toLowerCase())) {
                                  matched = m;
                                  break;
                                }
                              }
                              if (matched != null) {
                                Navigator.of(ctx).pop();
                                await _executeMemberToggle(matched);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Member not recognized. Please try again.'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Quick Member Scan Options
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Detected Members (Tap to simulate instant desk toggle):',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 10),

                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: members.length,
                        separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
                        itemBuilder: (c, idx) {
                          final m = members[idx];
                          final active = LocalCacheService().getActiveAttendance(m.id);
                          final isInside = active != null;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: (isInside ? AppColors.accent : AppColors.primary).withValues(alpha: 0.2),
                              child: Text(
                                m.name.isNotEmpty ? m.name[0].toUpperCase() : 'M',
                                style: TextStyle(
                                  color: isInside ? AppColors.accent : AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            title: Text(
                              m.name,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              isInside
                                  ? 'Currently Inside (In: ${DateFormat('hh:mm a').format(active.checkInTime)})'
                                  : 'Outside (Ready for Time-In)',
                              style: TextStyle(
                                color: isInside ? AppColors.accent : AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                Navigator.of(ctx).pop();
                                await _executeMemberToggle(m);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isInside ? AppColors.accent : AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                isInside ? 'Time Out' : 'Time In',
                                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _executeMemberToggle(UserModel member) async {
    final active = LocalCacheService().getActiveAttendance(member.id);
    final isInside = active != null;

    if (isInside) {
      // Time-Out is always permitted
      await ref.read(adminNotifierProvider.notifier).checkOutMember(member.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ TIME-OUT RECORDED: ${member.name} checked out!'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } else {
      // Time-In respects operating hours
      await _handleCheckInAttempt(member);
    }
  }
}
