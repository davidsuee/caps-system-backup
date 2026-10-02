import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../config/env.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/membership_entity.dart';
import '../../domain/entities/trainer_assignment_entity.dart';
import '../../domain/repositories/admin_repository.dart';
import '../models/user_model.dart';
import '../models/membership_model.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class AdminRepositoryImpl implements AdminRepository {
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  AdminRepositoryImpl({
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  List<UserModel> _enforceCoachCapacityLimits(List<UserModel> members, {Set<String>? localMemberIds}) {
    final Map<String, int> coachAssignedCount = {};
    final List<UserModel> sanitized = [];

    bool isDummyOrGhost(UserModel u) {
      final n = u.name.toLowerCase();
      final i = u.id.toLowerCase();
      if (n.contains('test') ||
          i.contains('test') ||
          n.contains('dummy') ||
          i.contains('dummy') ||
          i.contains('walker') ||
          n.contains('draven') ||
          i.contains('draven')) {
        return true;
      }
      if (localMemberIds != null && localMemberIds.isNotEmpty && !localMemberIds.contains(u.id)) {
        return true;
      }
      return false;
    }

    final sorted = List<UserModel>.from(members);
    sorted.sort((a, b) {
      final aGhost = isDummyOrGhost(a) ? 1 : 0;
      final bGhost = isDummyOrGhost(b) ? 1 : 0;
      return aGhost.compareTo(bGhost);
    });

    for (final m in sorted) {
      if (m.assignedCoachId != null && m.assignedCoachId!.isNotEmpty) {
        final coachId = m.assignedCoachId!;
        final current = coachAssignedCount[coachId] ?? 0;
        final isGhost = isDummyOrGhost(m);
        final coach = _localCache.getUserById(coachId);
        final maxCap = (coach != null && coach.maxClients > 0) ? coach.maxClients : 20;

        if (!isGhost && current < maxCap) {
          coachAssignedCount[coachId] = current + 1;
          sanitized.add(m);
        } else {
          // Strictly cap at coach's max limit, and unassign dummy/ghost overflow members
          final unassigned = UserModel.fromEntity(m.copyWith(assignedCoachId: null, clearAssignedCoach: true));
          sanitized.add(unassigned);
          _localCache.saveUser(unassigned);
        }
      } else {
        sanitized.add(m);
      }
    }
    return sanitized;
  }

  @override
  Future<List<UserModel>> getAllMembers() async {
    final localMembers = _localCache.getUsersByRole(UserRole.member);
    if (Env.useFirebase) {
      try {
        final remote = await _firestore.getUsersByRole(UserRole.member);
        if (remote.isNotEmpty) {
          final map = <String, UserModel>{};
          for (final u in remote) {
            map[u.id] = u;
          }
          for (final u in localMembers) {
            map[u.id] = u;
          }
          final merged = _enforceCoachCapacityLimits(
            map.values.toList(),
            localMemberIds: localMembers.map((m) => m.id).toSet(),
          );
          _localCache.saveUsers(merged);
          return merged;
        }
      } catch (_) {}
    }
    if (localMembers.isNotEmpty) return _enforceCoachCapacityLimits(localMembers);
    return _enforceCoachCapacityLimits(
      _localCache.getAllUsers().where((u) => u.role == UserRole.member).toList(),
    );
  }

  @override
  Future<List<UserModel>> getAllCoaches() async {
    final localCoaches = _localCache.getUsersByRole(UserRole.coach);
    if (Env.useFirebase) {
      try {
        final remote = await _firestore.getUsersByRole(UserRole.coach);
        if (remote.isNotEmpty) {
          final map = <String, UserModel>{};
          for (final u in localCoaches) {
            map[u.id] = u;
          }
          for (final u in remote) {
            map[u.id] = u;
          }
          final merged = map.values.toList();
          _localCache.saveUsers(merged);
          return merged;
        }
      } catch (_) {}
    }
    if (localCoaches.isNotEmpty) {
      return localCoaches.map((c) => c.maxClients < 20 ? UserModel.fromEntity(c.copyWith(maxClients: 20)) : c).toList();
    }
    final all = _localCache.getAllUsers().where((u) => u.role == UserRole.coach).toList();
    return all.map((c) => c.maxClients < 20 ? UserModel.fromEntity(c.copyWith(maxClients: 20)) : c).toList();
  }

  @override
  Future<List<MembershipModel>> getAllMemberships() async {
    if (Env.useFirebase) {
      try {
        final list = await _firestore.getAllMemberships();
        if (list.isNotEmpty) {
          final localMems = _localCache.getAllMemberships();
          final mergedMap = <String, MembershipModel>{};
          for (final m in localMems) {
            if (m.userId.isNotEmpty) mergedMap[m.userId] = m;
          }
          for (final m in list) {
            if (m.userId.isEmpty) continue;
            final existing = mergedMap[m.userId];
            if (existing == null) {
              mergedMap[m.userId] = m;
            } else {
              // ACTIVE status ALWAYS takes priority over pending or expired!
              if (existing.isActive && !m.isActive) {
                // Keep existing active
              } else if (!existing.isActive && m.isActive) {
                mergedMap[m.userId] = m;
              } else if (m.isPending && !existing.isActive && !existing.isPending) {
                mergedMap[m.userId] = m;
              } else if (m.startDate.isAfter(existing.startDate)) {
                mergedMap[m.userId] = m;
              }
            }
          }
          final mergedList = mergedMap.values.toList();
          _localCache.saveMemberships(mergedList);
          return mergedList;
        }
      } catch (_) {}
    }
    return _localCache.getAllMemberships();
  }

  @override
  Future<List<AttendanceModel>> getAllAttendance() async {
    if (Env.useFirebase) {
      try {
        final list = await _firestore.getAllAttendance();
        if (list.isNotEmpty) {
          _localCache.saveAttendanceList(list);
          final autoClosed = _localCache.autoCheckOutClosedSessions();
          final updatedList = _localCache.getAllAttendance();
          if (autoClosed) {
            for (final a in updatedList) {
              if (a.checkOutTime != null) {
                final remoteMatch = list.firstWhere(
                  (r) => r.id == a.id,
                  orElse: () => a,
                );
                if (remoteMatch.checkOutTime == null) {
                  _firestore.logAttendance(a).catchError((_) {});
                }
              }
            }
          }
          return updatedList;
        }
      } catch (_) {}
    }
    _localCache.autoCheckOutClosedSessions();
    return _localCache.getAllAttendance();
  }

  @override
  Future<AdminKpiData> getKpiMetrics() async {
    final memberships = await getAllMemberships();
    final members = await getAllMembers();
    final attendance = await getAllAttendance();

    final now = DateTime.now();

    // Compute monthly revenue (only count active paid memberships)
    final double revenue = memberships
        .where((m) => m.status == MembershipStatus.active)
        .fold(0.0, (sum, m) => sum + m.price);

    // Compute active members
    final activeCount = memberships.where((m) => m.isActive).length;
    final displayActive = activeCount > 0 ? activeCount : members.length;

    // Today checkins
    final todayCheckIns = attendance.where((a) {
      return a.checkInTime.year == now.year &&
          a.checkInTime.month == now.month &&
          a.checkInTime.day == now.day;
    }).length;

    // Retention
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

  @override
  Future<void> recordPayment({
    required String userId,
    required String planName,
    required double amount,
    required int durationDays,
  }) async {
    final now = DateTime.now();
    final existingMem = _localCache.getMembership(userId);
    final membershipId = (existingMem != null && existingMem.isPending)
        ? existingMem.id
        : const Uuid().v4();

    final newMembership = MembershipModel(
      id: membershipId,
      userId: userId,
      planName: planName,
      price: amount,
      startDate: now,
      endDate: now.add(Duration(days: durationDays)),
      status: MembershipStatus.active,
    );

    // Save locally first for zero-latency offline-first update
    _localCache.saveMembership(newMembership);

    if (Env.useFirebase) {
      try {
        await _firestore.saveMembership(newMembership);
      } catch (_) {}
    }
  }

  UserModel? _findBestCoachForMemberGoal(String memberGoal, List<UserModel> coaches) {
    if (coaches.isEmpty) return null;
    final goal = memberGoal.toLowerCase();

    // 1. Goal vs Specialization synergy:
    // - Weight Loss / Fat Burn / Cardio -> Coach Elena (Fat Loss & Functional HIIT)
    // - Muscle Gain / Hypertrophy / Bodybuilding -> Coach Dave (Bodybuilding & Hypertrophy)
    // - Endurance / Strength / Conditioning -> Coach Marcus (Strength & Conditioning)
    for (final coach in coaches) {
      final spec = (coach.specialization ?? '').toLowerCase();
      if ((goal.contains('weight') || goal.contains('fat') || goal.contains('loss') || goal.contains('cardio') || goal.contains('burn')) &&
          (spec.contains('fat') || spec.contains('loss') || spec.contains('hiit') || spec.contains('functional'))) {
        return coach;
      }
      if ((goal.contains('muscle') || goal.contains('gain') || goal.contains('hypertrophy') || goal.contains('bodybuilding')) &&
          (spec.contains('hypertrophy') || spec.contains('muscle') || spec.contains('bodybuilding'))) {
        return coach;
      }
      if ((goal.contains('strength') || goal.contains('endurance') || goal.contains('conditioning') || goal.contains('power') || goal.contains('stamina')) &&
          (spec.contains('strength') || spec.contains('conditioning') || spec.contains('endurance'))) {
        return coach;
      }
    }

    // 2. Secondary check against coach's own fitnessGoal / title
    for (final coach in coaches) {
      final cGoal = coach.fitnessGoal.toLowerCase();
      if (goal.contains('weight') && (cGoal.contains('cardio') || cGoal.contains('health'))) return coach;
      if (goal.contains('muscle') && (cGoal.contains('hypertrophy') || cGoal.contains('muscle'))) return coach;
      if (goal.contains('endurance') && (cGoal.contains('endurance') || cGoal.contains('strength'))) return coach;
    }

    // 3. Fallback: coach with lowest current client workload
    final allMembers = _localCache.getUsersByRole(UserRole.member);
    final sortedCoaches = List<UserModel>.from(coaches);
    sortedCoaches.sort((a, b) {
      final countA = allMembers.where((m) => m.assignedCoachId == a.id).length;
      final countB = allMembers.where((m) => m.assignedCoachId == b.id).length;
      return countA.compareTo(countB);
    });

    return sortedCoaches.first;
  }

  @override
  Future<void> approvePendingMembership(MembershipModel membership) async {
    final now = DateTime.now();
    final diff = membership.endDate.difference(membership.startDate).inDays;
    final durationDays = diff > 0 ? diff : 30;

    final approved = MembershipModel(
      id: membership.id,
      userId: membership.userId,
      planName: membership.planName,
      price: membership.price,
      startDate: now,
      endDate: now.add(Duration(days: durationDays)),
      status: MembershipStatus.active,
    );

    // Save locally first for instant UI response
    _localCache.saveMembership(approved);

    if (Env.useFirebase) {
      try {
        await _firestore.saveMembership(approved);
      } catch (_) {}
    }

    // Auto-assign to matching coach ONLY IF the plan includes coaching
    final planLower = membership.planName.toLowerCase();
    final bool planIncludesCoach = planLower.contains('pro') ||
        planLower.contains('vip') ||
        planLower.contains('coach') ||
        planLower.contains('trainer') ||
        planLower.contains('personal');

    if (planIncludesCoach) {
      UserModel? member = _localCache.getUserById(membership.userId);
      if (member == null && Env.useFirebase) {
        try {
          member = await _firestore.getUser(membership.userId);
        } catch (_) {}
      }

      if (member != null && (member.assignedCoachId == null || member.assignedCoachId!.isEmpty)) {
        final coaches = await getAllCoaches();
        if (coaches.isNotEmpty) {
          final bestCoach = _findBestCoachForMemberGoal(member.fitnessGoal, coaches);
          if (bestCoach != null) {
            final updatedMember = UserModel.fromEntity(member.copyWith(assignedCoachId: bestCoach.id));
            _localCache.saveUser(updatedMember);
            if (Env.useFirebase) {
              try {
                await _firestore.saveUser(updatedMember);
              } catch (_) {}
            }
          }
        }
      }
    } else {
      // If plan does not include a coach (e.g. Monthly Basic, Student, Day Pass), ensure member is not assigned to a coach
      UserModel? member = _localCache.getUserById(membership.userId);
      if (member == null && Env.useFirebase) {
        try {
          member = await _firestore.getUser(membership.userId);
        } catch (_) {}
      }
      if (member != null && member.assignedCoachId != null && member.assignedCoachId!.isNotEmpty) {
        final unassignedMember = UserModel.fromEntity(member.copyWith(assignedCoachId: null, clearAssignedCoach: true));
        _localCache.saveUser(unassignedMember);
        if (Env.useFirebase) {
          try {
            await _firestore.saveUser(unassignedMember);
          } catch (_) {}
        }
      }
    }
  }

  @override
  Future<void> rejectPendingMembership({required String membershipId, required String userId}) async {
    // Delete/expire locally first
    _localCache.deleteMembership(userId);
    _localCache.deleteMembershipById(membershipId);

    if (Env.useFirebase) {
      try {
        final expired = MembershipModel(
          id: membershipId,
          userId: userId,
          planName: 'None',
          price: 0,
          startDate: DateTime.now().subtract(const Duration(days: 30)),
          endDate: DateTime.now().subtract(const Duration(days: 1)),
          status: MembershipStatus.expired,
        );
        await _firestore.saveMembership(expired);
      } catch (_) {}
    }
  }

  @override
  Future<void> sendExpirationNotice({
    required String userId,
    required String title,
    required String message,
  }) async {
    final notice = AppNotificationModel(
      id: const Uuid().v4(),
      userId: userId,
      title: title,
      message: message,
      createdAt: DateTime.now(),
    );
    _localCache.addNotification(notice);
  }

  @override
  Future<void> assignMemberToCoach({
    required String memberId,
    required String coachId,
  }) async {
    final bool isUnassigning = coachId.trim().isEmpty;
    if (!isUnassigning) {
      final coach = _localCache.getUserById(coachId);
      final maxCap = (coach != null && coach.maxClients > 0) ? coach.maxClients : 20;
      final allMembers = await getAllMembers();
      final currentCount = allMembers.where((m) => m.assignedCoachId == coachId && m.id != memberId).length;
      if (currentCount >= maxCap) {
        throw Exception('Coach ${coach?.name ?? coachId} is at maximum capacity ($maxCap clients) and cannot accept new clients.');
      }
    }

    final allMembers = await getAllMembers();
    final member = _localCache.getUserById(memberId) ?? allMembers.where((m) => m.id == memberId).firstOrNull;
    if (member != null) {
      final updated = UserModel.fromEntity(
        member.copyWith(
          assignedCoachId: isUnassigning ? null : coachId,
          clearAssignedCoach: isUnassigning,
        ),
      );
      _localCache.saveUser(updated);
      if (Env.useFirebase) {
        try {
          await _firestore.saveUser(updated);
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> logMemberCheckIn(String userId) async {
    final now = DateTime.now();
    if (now.hour < 6 || now.hour >= 23) {
      throw Exception('Facility Closed: Member check-in is strictly disabled outside operating hours (6:00 AM – 11:00 PM).');
    }
    final att = AttendanceModel(
      id: const Uuid().v4(),
      userId: userId,
      checkInTime: now,
    );
    _localCache.logAttendance(att);

    // Reset exercise completion for the user's active workout plan so they have a fresh routine for their new check-in visit
    final activePlan = _localCache.getWorkoutPlan(userId);
    if (activePlan != null) {
      final resetExercises = activePlan.exercises.map((e) => e.copyWith(isCompleted: false)).toList();
      _localCache.saveWorkoutPlan(activePlan.copyWith(exercises: resetExercises));
    }

    if (Env.useFirebase) {
      try {
        await _firestore.logAttendance(att);
        debugPrint('[AdminRepo] Member check-in saved to Firebase: ${att.id}');
      } catch (e) {
        debugPrint('[AdminRepo] Firebase check-in error: $e');
      }
    }
  }

  @override
  Future<void> logMemberCheckOut(String userId) async {
    AttendanceModel? active = _localCache.getActiveAttendance(userId);
    if (active == null && Env.useFirebase) {
      try {
        final history = await _firestore.getAttendanceHistory(userId);
        for (final a in history) {
          if (a.checkOutTime == null) {
            active = a;
            break;
          }
        }
      } catch (_) {}
    }
    if (active != null) {
      final updated = AttendanceModel(
        id: active.id,
        userId: active.userId,
        checkInTime: active.checkInTime,
        checkOutTime: DateTime.now(),
      );
      _localCache.updateAttendance(updated);
      if (Env.useFirebase) {
        try {
          await _firestore.logAttendance(updated);
          debugPrint('[AdminRepo] Member check-out saved to Firebase: ${updated.id}');
        } catch (e) {
          debugPrint('[AdminRepo] Firebase check-out error: $e');
        }
      }
    }
  }

  @override
  Future<AssignmentOptimizationResult> runTrainerAssignmentOptimization() async {
    final members = await getAllMembers();
    final coaches = await getAllCoaches();
    final memberships = await getAllMemberships();

    if (coaches.isEmpty || members.isEmpty) {
      return AssignmentOptimizationResult(
        totalEvaluated: members.length,
        newlyAssignedCount: 0,
        matches: const [],
        executedAt: DateTime.now(),
      );
    }

    // Helper to identify Day Pass / Walk-in members (Autonomous / Self-Directed)
    bool isDayPassMember(String userId) {
      final userMems = memberships.where((m) => m.userId == userId).toList();
      if (userMems.isNotEmpty) {
        userMems.sort((a, b) => b.endDate.compareTo(a.endDate));
        final latest = userMems.first;
        final name = latest.planName.toLowerCase();
        if (name.contains('day') || name.contains('walk')) return true;
      }
      final cached = _localCache.getMembership(userId);
      if (cached != null) {
        final name = cached.planName.toLowerCase();
        if (name.contains('day') || name.contains('walk')) return true;
      }
      return false;
    }

    // Day Pass / Walk-in customers do NOT consume coach capacity
    final eligibleMembers = members.where((m) => !isDayPassMember(m.id)).toList();

    // Determine candidate members: prioritize unassigned members among eligible coaching clients
    List<UserModel> candidates = eligibleMembers.where((m) => m.assignedCoachId == null || m.assignedCoachId!.isEmpty).toList();
    final bool reoptimizingAll = candidates.isEmpty;
    if (reoptimizingAll) {
      candidates = List.from(eligibleMembers);
    }
    // Prioritize newest registered members first so newly created customers get matched immediately
    candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Map coach current client counts (strictly counting eligible coaching clients)
    final Map<String, int> coachClientCount = {};
    for (final c in coaches) {
      if (reoptimizingAll) {
        coachClientCount[c.id] = 0;
      } else {
        coachClientCount[c.id] = eligibleMembers.where((m) => m.assignedCoachId == c.id).length;
      }
    }

    final List<AssignmentMatch> matches = [];

    for (final member in candidates) {
      UserModel? bestCoach;
      int bestScore = -1;
      String bestReason = '';

      for (final coach in coaches) {
        final currentLoad = coachClientCount[coach.id] ?? 0;
        final maxCap = coach.maxClients > 0 ? coach.maxClients : 20;

        // STRICT CAPACITY ENFORCEMENT:
        // When coach reaches maximum client limit, they CANNOT accept any new client!
        if (currentLoad >= maxCap) {
          continue;
        }

        // 1. Goal vs Specialization synergy (up to 40 pts)
        final goal = member.fitnessGoal.toLowerCase();
        final spec = (coach.specialization ?? '').toLowerCase();
        int specScore = 20; // baseline compatibility

        if ((goal.contains('weight') || goal.contains('fat') || goal.contains('loss') || goal.contains('cardio')) &&
            (spec.contains('fat') || spec.contains('loss') || spec.contains('hiit') || spec.contains('functional'))) {
          specScore = 40;
        } else if ((goal.contains('muscle') || goal.contains('gain') || goal.contains('hypertrophy') || goal.contains('bodybuilding')) &&
            (spec.contains('hypertrophy') || spec.contains('muscle') || spec.contains('bodybuilding'))) {
          specScore = 40;
        } else if ((goal.contains('strength') || goal.contains('endurance') || goal.contains('conditioning') || goal.contains('power')) &&
            (spec.contains('strength') || spec.contains('conditioning'))) {
          specScore = 40;
        }

        // 2. Workload balance score (up to 40 pts - inverse of load ratio)
        final ratio = (currentLoad / maxCap).clamp(0.0, 1.0);
        final workloadScore = ((1.0 - (ratio * 0.5)) * 40).round();

        // 3. Experience & demographics compatibility (up to 20 pts)
        final expScore = 15;

        final totalScore = (specScore + workloadScore + expScore).clamp(40, 99);

        if (totalScore > bestScore) {
          bestScore = totalScore;
          bestCoach = coach;
          bestReason = 'Synergy: Goal "${member.fitnessGoal}" matches "${coach.specialization ?? 'General Fitness'}" (+$specScore pts) + Workload balance (+$workloadScore pts)';
        }
      }

      if (bestCoach != null) {
        coachClientCount[bestCoach.id] = (coachClientCount[bestCoach.id] ?? 0) + 1;
        final updatedMember = UserModel.fromEntity(member.copyWith(assignedCoachId: bestCoach.id));
        _localCache.saveUser(updatedMember);
        if (Env.useFirebase) {
          _firestore.saveUser(updatedMember).catchError((_) {});
        }

        matches.add(AssignmentMatch(
          memberId: member.id,
          memberName: member.name,
          memberGoal: member.fitnessGoal,
          coachId: bestCoach.id,
          coachName: bestCoach.name,
          coachSpecialization: bestCoach.specialization ?? 'General Fitness',
          matchScore: bestScore,
          matchReason: bestReason,
        ));
      }
    }

    return AssignmentOptimizationResult(
      totalEvaluated: candidates.length,
      newlyAssignedCount: matches.length,
      matches: matches,
      executedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateCoachCapacity({
    required String coachId,
    required int maxClients,
  }) async {
    final coach = _localCache.getUserById(coachId);
    if (coach != null) {
      final updated = UserModel.fromEntity(coach.copyWith(maxClients: maxClients));
      _localCache.saveUser(updated);
      if (Env.useFirebase) {
        try {
          await _firestore.saveUser(updated);
        } catch (_) {}
      }
    }
  }
}

