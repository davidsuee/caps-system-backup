import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/membership_model.dart';
import '../../../data/models/walk_in_record_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/membership_entity.dart';
import '../../../domain/entities/trainer_assignment_entity.dart';
import '../../../domain/repositories/admin_repository.dart';
import '../../../data/repositories/admin_repository_impl.dart';
import '../../../data/repositories/membership_repository_impl.dart';
import '../../../data/datasources/local/local_cache_service.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl();
});

class AdminState {
  final bool isLoading;
  final String? errorMessage;
  final List<UserModel> members;
  final List<UserModel> coaches;
  final List<MembershipModel> memberships;
  final List<AttendanceModel> attendance;
  final List<WalkInRecordModel> walkIns;
  final AdminKpiData? kpi;
  final String searchQuery;
  final AssignmentOptimizationResult? lastOptimizationResult;

  const AdminState({
    this.isLoading = false,
    this.errorMessage,
    this.members = const [],
    this.coaches = const [],
    this.memberships = const [],
    this.attendance = const [],
    this.walkIns = const [],
    this.kpi,
    this.searchQuery = '',
    this.lastOptimizationResult,
  });

  List<UserModel> get filteredMembers {
    if (searchQuery.trim().isEmpty) return members;
    final q = searchQuery.toLowerCase().trim();
    return members.where((m) =>
      m.name.toLowerCase().contains(q) ||
      m.email.toLowerCase().contains(q) ||
      m.fitnessGoal.toLowerCase().contains(q) ||
      m.experienceLevel.toLowerCase().contains(q)
    ).toList();
  }

  MembershipModel? getMembershipForUser(String userId) {
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

  List<MembershipModel> get pendingMemberships {
    final activeUserIds = memberships
        .where((m) => m.status == MembershipStatus.active && m.isActive)
        .map((m) => m.userId)
        .toSet();

    final seen = <String>{};
    final list = <MembershipModel>[];
    for (final m in memberships) {
      if (m.status == MembershipStatus.pending &&
          m.userId.isNotEmpty &&
          !activeUserIds.contains(m.userId) &&
          !seen.contains(m.userId)) {
        seen.add(m.userId);
        list.add(m);
      }
    }
    return list;
  }

  AdminState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<UserModel>? members,
    List<UserModel>? coaches,
    List<MembershipModel>? memberships,
    List<AttendanceModel>? attendance,
    List<WalkInRecordModel>? walkIns,
    AdminKpiData? kpi,
    String? searchQuery,
    AssignmentOptimizationResult? lastOptimizationResult,
  }) {
    return AdminState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      members: members ?? this.members,
      coaches: coaches ?? this.coaches,
      memberships: memberships ?? this.memberships,
      attendance: attendance ?? this.attendance,
      walkIns: walkIns ?? this.walkIns,
      kpi: kpi ?? this.kpi,
      searchQuery: searchQuery ?? this.searchQuery,
      lastOptimizationResult: lastOptimizationResult ?? this.lastOptimizationResult,
    );
  }
}

class AdminNotifier extends Notifier<AdminState> {
  late AdminRepository _repo;
  StreamSubscription? _attendanceSub;
  Timer? _liveSyncTimer;

  @override
  AdminState build() {
    _repo = ref.read(adminRepositoryProvider);
    final cachedMembers = LocalCacheService().getUsersByRole(UserRole.member);
    final cachedCoaches = LocalCacheService().getUsersByRole(UserRole.coach);
    final cachedMemberships = LocalCacheService().getAllMemberships();
    final cachedAttendance = LocalCacheService().getAllAttendance();

    _attendanceSub?.cancel();
    _liveSyncTimer?.cancel();

    ref.onDispose(() {
      _attendanceSub?.cancel();
      _liveSyncTimer?.cancel();
    });

    // Real-time listener: instantly update admin state when any user checks in or checks out
    _attendanceSub = MembershipRepositoryImpl.attendanceStream.listen((_) {
      _refreshAttendanceOnly();
    });

    // Periodic live sync every 5 seconds to sync cloud attendance in real time
    _liveSyncTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshAttendanceOnly();
    });

    Future.microtask(loadDashboard);
    return AdminState(
      isLoading: true,
      members: cachedMembers,
      coaches: cachedCoaches,
      memberships: cachedMemberships,
      attendance: cachedAttendance,
    );
  }

  Future<void> _refreshAttendanceOnly() async {
    try {
      final list = await _repo.getAllAttendance();
      if (!ref.mounted) return;
      final kpi = _computeKpiMetrics(state.memberships, state.members, list);
      state = state.copyWith(
        attendance: list,
        kpi: kpi,
      );
    } catch (_) {}
  }

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final results = await Future.wait([
        _repo.getAllMembers(),
        _repo.getAllCoaches(),
        _repo.getAllMemberships(),
        _repo.getAllAttendance(),
      ]).timeout(
        const Duration(seconds: 15),
        onTimeout: () => [
          LocalCacheService().getUsersByRole(UserRole.member),
          LocalCacheService().getUsersByRole(UserRole.coach),
          LocalCacheService().getAllMemberships(),
          LocalCacheService().getAllAttendance(),
        ],
      );

      final members = results[0] as List<UserModel>;
      final coaches = results[1] as List<UserModel>;
      final memberships = results[2] as List<MembershipModel>;
      final attendance = results[3] as List<AttendanceModel>;

      final kpi = _computeKpiMetrics(memberships, members, attendance);

      if (!ref.mounted) return;
      final walkIns = LocalCacheService().getAllWalkInRecords();
      state = state.copyWith(
        isLoading: false,
        members: members,
        coaches: coaches,
        memberships: memberships,
        attendance: attendance,
        walkIns: walkIns,
        kpi: kpi,
      );
    } catch (e) {
      if (!ref.mounted) return;
      // Fallback to cached data on error
      final cachedMembers = LocalCacheService().getUsersByRole(UserRole.member);
      final cachedCoaches = LocalCacheService().getUsersByRole(UserRole.coach);
      final cachedMemberships = LocalCacheService().getAllMemberships();
      final cachedAttendance = LocalCacheService().getAllAttendance();
      final cachedWalkIns = LocalCacheService().getAllWalkInRecords();
      final kpi = _computeKpiMetrics(cachedMemberships, cachedMembers, cachedAttendance);

      state = state.copyWith(
        isLoading: false,
        members: cachedMembers.isNotEmpty ? cachedMembers : state.members,
        coaches: cachedCoaches.isNotEmpty ? cachedCoaches : state.coaches,
        memberships: cachedMemberships.isNotEmpty ? cachedMemberships : state.memberships,
        attendance: cachedAttendance.isNotEmpty ? cachedAttendance : state.attendance,
        walkIns: cachedWalkIns.isNotEmpty ? cachedWalkIns : state.walkIns,
        kpi: kpi,
        errorMessage: e.toString(),
      );
    }
  }

  AdminKpiData _computeKpiMetrics(
    List<MembershipModel> memberships,
    List<UserModel> members,
    List<AttendanceModel> attendance,
  ) {
    final now = DateTime.now();

    final double revenue = memberships
        .where((m) => m.status == MembershipStatus.active)
        .fold(0.0, (sum, m) => sum + m.price);

    final activeCount = memberships.where((m) => m.isActive).length;
    final displayActive = activeCount > 0 ? activeCount : members.length;

    final todayCheckIns = attendance.where((a) {
      return a.checkInTime.year == now.year &&
          a.checkInTime.month == now.month &&
          a.checkInTime.day == now.day;
    }).length;

    final double retention = memberships.isNotEmpty
        ? ((memberships.where((m) => m.isActive).length / memberships.length) * 100).clamp(0.0, 100.0)
        : 95.0;

    return AdminKpiData(
      monthlyRevenue: revenue > 0 ? revenue : 1500.0 * displayActive,
      activeMembersCount: displayActive,
      todayCheckInsCount: todayCheckIns,
      retentionRate: retention,
    );
  }

  void setSearchQuery(String query) {
    if (!ref.mounted) return;
    state = state.copyWith(searchQuery: query);
  }

  Future<bool> recordPayment({
    required String userId,
    required String planName,
    required double amount,
    required int durationDays,
  }) async {
    try {
      await _repo.recordPayment(
        userId: userId,
        planName: planName,
        amount: amount,
        durationDays: durationDays,
      );
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> logWalkIn({
    required String guestName,
    String? contactNumber,
    double amountPaid = 150.0,
    double? amount,
    String paymentMethod = 'Cash at Counter',
    String? notes,
  }) async {
    try {
      final actualAmount = amount ?? amountPaid;
      final record = WalkInRecordModel(
        id: 'walkin_${DateTime.now().millisecondsSinceEpoch}',
        guestName: guestName,
        contactNumber: contactNumber,
        amountPaid: actualAmount,
        paymentMethod: paymentMethod,
        checkInTime: DateTime.now(),
        notes: notes,
      );
      LocalCacheService().logWalkInRecord(record);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> checkOutWalkIn(String walkInId) async {
    try {
      LocalCacheService().checkOutWalkInRecord(walkInId);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> approveMembership(MembershipModel membership) async {
    try {
      await _repo.approvePendingMembership(membership);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> rejectMembership({
    required String membershipId,
    required String userId,
  }) async {
    try {
      await _repo.rejectPendingMembership(
        membershipId: membershipId,
        userId: userId,
      );
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> sendExpirationNotice({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      await _repo.sendExpirationNotice(
        userId: userId,
        title: title,
        message: message,
      );
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> checkInMember(String userId) async {
    try {
      await _repo.logMemberCheckIn(userId);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> checkOutMember(String userId) async {
    try {
      await _repo.logMemberCheckOut(userId);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<AssignmentOptimizationResult?> runAutoAssignmentOptimization() async {
    if (ref.mounted) {
      state = state.copyWith(isLoading: true, errorMessage: null);
    }
    try {
      final result = await _repo.runTrainerAssignmentOptimization();
      await loadDashboard();
      if (ref.mounted) {
        state = state.copyWith(lastOptimizationResult: result, isLoading: false);
      }
      return result;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(isLoading: false, errorMessage: e.toString());
      }
      return null;
    }
  }

  Future<bool> manuallyAssignCoach({
    required String memberId,
    required String coachId,
  }) async {
    try {
      await _repo.assignMemberToCoach(memberId: memberId, coachId: coachId);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }

  Future<bool> updateCoachCapacity({
    required String coachId,
    required int maxClients,
  }) async {
    try {
      await _repo.updateCoachCapacity(coachId: coachId, maxClients: maxClients);
      await loadDashboard();
      return true;
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(errorMessage: e.toString());
      }
      return false;
    }
  }
}

final adminNotifierProvider = NotifierProvider<AdminNotifier, AdminState>(AdminNotifier.new);
