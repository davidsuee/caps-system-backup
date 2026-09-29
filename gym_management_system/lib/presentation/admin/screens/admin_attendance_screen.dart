import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../data/models/membership_model.dart';
import '../../../data/models/user_model.dart';
import '../providers/admin_provider.dart';

class AdminAttendanceScreen extends ConsumerStatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  ConsumerState<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends ConsumerState<AdminAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedUserId;
  String _searchQuery = '';
  Timer? _liveSyncTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      if (mounted) {
        ref.read(adminNotifierProvider.notifier).loadDashboard();
      }
    });

    // Auto sync dashboard every 4 seconds for real-time tracking
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        ref.read(adminNotifierProvider.notifier).loadDashboard();
      }
    });
  }

  @override
  void dispose() {
    _liveSyncTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminNotifierProvider);
    final members = adminState.members;
    final allAttendance = adminState.attendance.isNotEmpty
        ? adminState.attendance
        : LocalCacheService().getAllAttendance();

    // Default select first member if null
    if (_selectedUserId == null && members.isNotEmpty) {
      _selectedUserId = members.first.id;
    }

    final now = DateTime.now();
    final todayLogs = allAttendance.where((a) {
      return a.checkInTime.year == now.year &&
          a.checkInTime.month == now.month &&
          a.checkInTime.day == now.day;
    }).toList();

    final activeSessions = allAttendance.where((a) => a.checkOutTime == null).toList();

    AttendanceModel? selectedUserActive;
    if (_selectedUserId != null) {
      for (final a in allAttendance) {
        if (a.userId == _selectedUserId && a.checkOutTime == null) {
          selectedUserActive = a;
          break;
        }
      }
      selectedUserActive ??= LocalCacheService().getActiveAttendance(_selectedUserId!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Customer Attendance Registry',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            tooltip: 'Scan Member QR Pass',
            onPressed: () => _showAdminQrScannerModal(context, members),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
            tooltip: 'Refresh',
            onPressed: () => ref.read(adminNotifierProvider.notifier).loadDashboard(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          tabs: [
            Tab(text: 'All Logs (${allAttendance.length})'),
            Tab(text: 'In Gym (${activeSessions.length})'),
            Tab(text: 'Today (${todayLogs.length})'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Counter Check-In / Check-Out Box (Front Desk Tool)
          _buildCounterTool(context, members, selectedUserActive),
          const SizedBox(height: 16),

          // Live KPIs
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  '${todayLogs.length}',
                  "Today's Check-Ins",
                  AppColors.primary,
                  Icons.login_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  '${activeSessions.length}',
                  'Currently Inside',
                  AppColors.accentCyan,
                  Icons.fitness_center_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search member by name or email...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                icon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Attendance Lists Tab Content
          SizedBox(
            height: 520,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAttendanceList(allAttendance, members),
                _buildAttendanceList(activeSessions, members),
                _buildAttendanceList(todayLogs, members),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- COUNTER ACTION TOOL ---
  Widget _buildCounterTool(
    BuildContext context,
    List<UserModel> members,
    AttendanceModel? selectedUserActive,
  ) {
    final isInside = selectedUserActive != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isInside ? AppColors.accent.withValues(alpha: 0.5) : AppColors.primary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (isInside ? AppColors.accent : AppColors.primary).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.storefront_rounded,
                  color: isInside ? AppColors.accent : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Front Desk Counter Attendance Check',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Select member or scan member QR pass',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showAdminQrScannerModal(context, members),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.primary),
                label: const Text('Scan QR', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Member Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedUserId,
                isExpanded: true,
                dropdownColor: AppColors.surface,
                items: members.map<DropdownMenuItem<String>>((m) {
                  final inGym = LocalCacheService().getActiveAttendance(m.id) != null;
                  return DropdownMenuItem<String>(
                    value: m.id,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${m.name} (${m.email})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                          ),
                        ),
                        if (inGym)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'INSIDE',
                              style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedUserId = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Button
          if (_selectedUserId != null) ...[
            if (!isInside)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await ref.read(adminNotifierProvider.notifier).checkInMember(_selectedUserId!);
                    setState(() {});
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ok ? 'Member checked in successfully!' : 'Failed to check in.'),
                          backgroundColor: ok ? AppColors.primary : AppColors.error,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.login_rounded, size: 18, color: Colors.black),
                  label: const Text(
                    'Log Customer Time In (Check-In)',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Session Active since: ${DateFormat('hh:mm a').format(selectedUserActive.checkInTime)}',
                        style: const TextStyle(color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await ref.read(adminNotifierProvider.notifier).checkOutMember(_selectedUserId!);
                      setState(() {});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Member checked out successfully!' : 'Failed to check out.'),
                            backgroundColor: ok ? AppColors.accent : AppColors.error,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.black),
                    label: const Text(
                      'Check-Out',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildKpiCard(String val, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  val,
                  style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  UserModel? _findMember(String userId, List<UserModel> members) {
    for (final m in members) {
      if (m.id == userId) return m;
    }
    return LocalCacheService().getUserById(userId);
  }

  Widget _buildAttendanceList(List<AttendanceModel> list, List<UserModel> members) {
    final filtered = list.where((a) {
      if (_searchQuery.isEmpty) return true;
      final member = _findMember(a.userId, members);
      if (member == null) return false;
      return member.name.toLowerCase().contains(_searchQuery) ||
          member.email.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy_rounded, color: AppColors.textMuted, size: 36),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty ? 'No attendance records match "$_searchQuery"' : 'No attendance logs recorded in this view.',
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
        final member = _findMember(item.userId, members);
        final isOut = item.checkOutTime != null;

        String durationStr = 'Active Now';
        if (isOut) {
          final diff = item.checkOutTime!.difference(item.checkInTime);
          if (diff.inHours > 0) {
            durationStr = '${diff.inHours}h ${diff.inMinutes % 60}m';
          } else {
            durationStr = '${diff.inMinutes} mins';
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOut ? AppColors.border : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (isOut ? AppColors.surfaceLight : AppColors.primary).withValues(alpha: 0.2),
                child: Text(
                  (member?.name.isNotEmpty ?? false) ? member!.name.substring(0, 1).toUpperCase() : 'M',
                  style: TextStyle(
                    color: isOut ? AppColors.textPrimary : AppColors.primary,
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
                      member?.name ?? 'Customer (${item.userId})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'In: ${DateFormat('hh:mm a, MMM dd').format(item.checkInTime)}',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    if (isOut)
                      Text(
                        'Out: ${DateFormat('hh:mm a').format(item.checkOutTime!)} • Duration: $durationStr',
                        style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!isOut)
                ElevatedButton(
                  onPressed: () async {
                    await ref.read(adminNotifierProvider.notifier).checkOutMember(item.userId);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
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
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Checked Out',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

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
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
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
                          child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reception QR Attendance Terminal',
                                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Scan customer digital QR pass or select member to auto log',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Scanner Viewfinder Screen
                    Container(
                      width: double.infinity,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2_rounded, color: AppColors.primary, size: 44),
                              const SizedBox(height: 8),
                              const Text(
                                'AIMING AT CUSTOMER QR PASS...',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Optical Terminal: VISCOUS-FRONT-DESK-01',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                              ),
                            ],
                          ),
                          // Viewfinder Reticle Corners
                          Positioned(top: 10, left: 10, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.primary, width: 2.5), left: BorderSide(color: AppColors.primary, width: 2.5))))),
                          Positioned(top: 10, right: 10, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.primary, width: 2.5), right: BorderSide(color: AppColors.primary, width: 2.5))))),
                          Positioned(bottom: 10, left: 10, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2.5), left: BorderSide(color: AppColors.primary, width: 2.5))))),
                          Positioned(bottom: 10, right: 10, child: Container(width: 20, height: 20, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.primary, width: 2.5), right: BorderSide(color: AppColors.primary, width: 2.5))))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Manual Text Scan / Barcode Input
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.barcode_reader, color: AppColors.textMuted, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: textCtrl,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Paste or type QR raw payload / Member UID...',
                                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                            onPressed: () async {
                              final text = textCtrl.text.trim();
                              if (text.isEmpty) return;
                              // Match member by UID or name in QR payload
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
                                    content: Text('Member QR pass not recognized. Please try again.'),
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
                        'Detected Member Passes (Tap to simulate instant scan):',
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
                                m.name.isNotEmpty ? m.name.substring(0, 1).toUpperCase() : 'M',
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
                                isInside ? 'Scan Out' : 'Scan In',
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
      await ref.read(adminNotifierProvider.notifier).checkInMember(member.id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ TIME-IN RECORDED: ${member.name} checked in!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }
}
