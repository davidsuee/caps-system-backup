import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../domain/entities/membership_entity.dart';
import '../../../domain/repositories/membership_repository.dart';
import '../../../data/repositories/membership_repository_impl.dart';
import '../../auth/providers/auth_provider.dart';

final membershipRepositoryProvider = Provider<MembershipRepository>((ref) {
  return MembershipRepositoryImpl();
});

class MembershipState {
  final MembershipEntity? membership;
  final List<AttendanceEntity> attendanceHistory;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const MembershipState({
    this.membership,
    this.attendanceHistory = const [],
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  AttendanceEntity? get activeAttendance {
    return attendanceHistory.where((a) => a.checkOutTime == null).firstOrNull;
  }

  bool get isCurrentlyCheckedIn => activeAttendance != null;

  MembershipState copyWith({
    MembershipEntity? membership,
    bool clearMembership = false,
    List<AttendanceEntity>? attendanceHistory,
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return MembershipState(
      membership: clearMembership ? null : (membership ?? this.membership),
      attendanceHistory: attendanceHistory ?? this.attendanceHistory,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class MembershipNotifier extends Notifier<MembershipState> {
  late MembershipRepository _repo;
  StreamSubscription<List<AttendanceEntity>>? _streamSub;
  String? _subscribedUserId;

  @override
  MembershipState build() {
    _repo = ref.read(membershipRepositoryProvider);
    final user = ref.watch(authNotifierProvider).user;

    ref.onDispose(() {
      _streamSub?.cancel();
    });

    if (user != null) {
      // 1. Instantly preload from local cache so hot restart NEVER wipes data
      final cachedAtt = LocalCacheService().getAttendance(user.id);
      final cachedMem = LocalCacheService().getMembership(user.id);

      _setupStreamSubscription(user.id);

      Future.microtask(() => loadUserData(user.id));
      return MembershipState(
        membership: cachedMem,
        attendanceHistory: cachedAtt,
      );
    }

    _streamSub?.cancel();
    _subscribedUserId = null;
    return const MembershipState();
  }

  void _setupStreamSubscription(String userId) {
    if (_subscribedUserId == userId && _streamSub != null) return;
    _streamSub?.cancel();
    _subscribedUserId = userId;
    _streamSub = _repo.watchUserAttendance(userId).listen((list) {
      if (list.isNotEmpty || state.attendanceHistory.isEmpty) {
        state = state.copyWith(attendanceHistory: list);
      }
    });
  }

  void reset() {
    _streamSub?.cancel();
    _subscribedUserId = null;
    state = const MembershipState();
  }

  Future<void> loadUserData(String userId) async {
    try {
      final mem = await _repo.getUserMembership(userId);
      final att = await _repo.getAttendanceHistory(userId);
      state = state.copyWith(
        membership: mem,
        clearMembership: mem == null,
        attendanceHistory: att,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> checkIn(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repo.logCheckIn(userId);
      final att = await _repo.getAttendanceHistory(userId);
      state = state.copyWith(
        attendanceHistory: att,
        isLoading: false,
        successMessage: 'Check-in recorded successfully! Have a great workout!',
      );
    } catch (e) {
      final att = await _repo.getAttendanceHistory(userId);
      state = state.copyWith(
        attendanceHistory: att,
        isLoading: false,
        errorMessage: 'Notice: Check-in saved. Syncing with cloud.',
      );
    }
  }

  Future<void> checkOut(String userId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      await _repo.logCheckOut(userId);
      final att = await _repo.getAttendanceHistory(userId);
      state = state.copyWith(
        attendanceHistory: att,
        isLoading: false,
        successMessage: 'Check-out recorded successfully! Great workout today!',
      );
    } catch (e) {
      final att = await _repo.getAttendanceHistory(userId);
      state = state.copyWith(
        attendanceHistory: att,
        isLoading: false,
        errorMessage: 'Notice: Check-out saved. Syncing with cloud.',
      );
    }
  }

  Future<bool> toggleCheckInOrOut(String userId) async {
    if (state.isCurrentlyCheckedIn) {
      await checkOut(userId);
      return false; // Checked out
    } else {
      await checkIn(userId);
      return true; // Checked in
    }
  }

  Future<void> purchasePlan(MembershipEntity plan) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.purchaseOrRenewMembership(plan);
      state = state.copyWith(
        membership: plan,
        isLoading: false,
        successMessage: 'Membership activated successfully!',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> requestCashPlan(MembershipEntity plan) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repo.purchaseOrRenewMembership(plan);
      state = state.copyWith(
        membership: plan,
        isLoading: false,
        successMessage: 'Membership request submitted! Please pay cash at the gym counter to activate.',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final membershipNotifierProvider = NotifierProvider<MembershipNotifier, MembershipState>(MembershipNotifier.new);

