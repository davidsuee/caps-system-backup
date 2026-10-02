import 'package:flutter/foundation.dart';
import '../../config/env.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/coach_repository.dart';
import '../models/user_model.dart';
import '../models/workout_plan_model.dart';
import '../models/meal_plan_model.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class CoachRepositoryImpl implements CoachRepository {
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  CoachRepositoryImpl({
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  bool _isDayPassMember(String userId) {
    final m = _localCache.getMembership(userId);
    if (m != null) {
      final name = m.planName.toLowerCase();
      return name.contains('day') || name.contains('walk');
    }
    return false;
  }

  @override
  List<UserModel> getCachedAssignedClients() {
    final currentUser = _localCache.getCurrentUser();
    final allMembers = _localCache.getUsersByRole(UserRole.member);
    final eligibleMembers = allMembers.where((u) => !_isDayPassMember(u.id)).toList();

    if (currentUser != null && currentUser.role == UserRole.coach) {
      final specific = eligibleMembers.where((u) => u.assignedCoachId == currentUser.id).toList();
      final maxCap = (currentUser.maxClients > 0) ? currentUser.maxClients : 20;

      // STRICT CAPACITY ENFORCEMENT: Max 20 clients per coach!
      if (specific.length > maxCap) {
        final allowed = specific.sublist(0, maxCap);
        final overflow = specific.sublist(maxCap);
        for (final over in overflow) {
          final unassigned = UserModel.fromEntity(over.copyWith(assignedCoachId: null, clearAssignedCoach: true));
          _localCache.saveUser(unassigned);
        }
        return allowed;
      }
      return specific;
    }
    return [];
  }

  @override
  Map<String, WorkoutPlanModel?> getCachedWorkoutPlans() {
    final Map<String, WorkoutPlanModel?> map = {};
    for (final user in getCachedAssignedClients()) {
      final cached = _localCache.getWorkoutPlan(user.id);
      if (cached != null) map[user.id] = cached;
    }
    return map;
  }

  @override
  Map<String, MealPlanModel?> getCachedMealPlans() {
    final Map<String, MealPlanModel?> map = {};
    for (final user in getCachedAssignedClients()) {
      final cached = _localCache.getMealPlan(user.id);
      if (cached != null) map[user.id] = cached;
    }
    return map;
  }

  @override
  Future<List<UserModel>> getAssignedClients() async {
    if (Env.useFirebase) {
      try {
        final users = await _firestore.getUsersByRole(UserRole.member);
        if (users.isNotEmpty) {
          _localCache.saveUsers(users);
        }
      } catch (e) {
        debugPrint('[CoachRepo] Error getting assigned clients: $e');
      }
    }
    return getCachedAssignedClients();
  }

  @override
  Future<Map<String, WorkoutPlanModel?>> getAllClientWorkoutPlans() async {
    final map = getCachedWorkoutPlans();
    if (Env.useFirebase) {
      try {
        final plans = await _firestore.getAllWorkoutPlans();
        for (final p in plans) {
          if (p.userId.isEmpty) continue;
          final existing = map[p.userId];
          if (existing == null || p.generatedAt.isAfter(existing.generatedAt)) {
            map[p.userId] = p;
            _localCache.saveWorkoutPlan(p);
          }
        }
      } catch (e) {
        debugPrint('[CoachRepo] Error getting all workout plans: $e');
      }
    }
    return map;
  }

  @override
  Future<Map<String, MealPlanModel?>> getAllClientMealPlans() async {
    final map = getCachedMealPlans();
    if (Env.useFirebase) {
      try {
        final plans = await _firestore.getAllMealPlans();
        for (final p in plans) {
          if (p.userId.isEmpty) continue;
          final existing = map[p.userId];
          if (existing == null || p.generatedAt.isAfter(existing.generatedAt)) {
            map[p.userId] = p;
            _localCache.saveMealPlan(p);
          }
        }
      } catch (e) {
        debugPrint('[CoachRepo] Error getting all meal plans: $e');
      }
    }
    return map;
  }

  @override
  Future<WorkoutPlanModel?> getClientWorkoutPlan(String clientUserId) async {
    if (Env.useFirebase) {
      try {
        final plan = await _firestore.getLatestWorkoutPlan(clientUserId);
        if (plan != null) return plan;
      } catch (_) {}
    }
    return _localCache.getWorkoutPlan(clientUserId);
  }

  @override
  Future<MealPlanModel?> getClientMealPlan(String clientUserId) async {
    if (Env.useFirebase) {
      try {
        final plan = await _firestore.getLatestMealPlan(clientUserId);
        if (plan != null) return plan;
      } catch (_) {}
    }
    return _localCache.getMealPlan(clientUserId);
  }

  @override
  Future<void> approveWorkoutPlan(String clientUserId, {String? notes}) async {
    _localCache.approveWorkoutPlan(clientUserId, notes);
    if (Env.useFirebase) {
      try {
        final plan = await _firestore.getLatestWorkoutPlan(clientUserId);
        if (plan != null) {
          final updated = plan.copyWith(isCoachApproved: true, coachNotes: notes);
          await _firestore.saveWorkoutPlan(updated);
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> approveMealPlan(String clientUserId, {String? notes}) async {
    _localCache.approveMealPlan(clientUserId, notes);
    if (Env.useFirebase) {
      try {
        final plan = await _firestore.getLatestMealPlan(clientUserId);
        if (plan != null) {
          final updated = plan.copyWith(isCoachApproved: true, coachNotes: notes);
          await _firestore.saveMealPlan(updated);
        }
      } catch (_) {}
    }
  }

  @override
  Future<List<TrainingSessionModel>> getCoachSessions(String coachId) async {
    return _localCache.getCoachSessions(coachId);
  }

  @override
  Future<void> scheduleSession(TrainingSessionModel session) async {
    final h = session.dateTime.hour;
    final m = session.dateTime.minute;
    if (h < 8 || h > 23 || (h == 23 && m > 0)) {
      throw Exception('Cannot schedule session outside gym operating hours (8:00 AM – 11:00 PM).');
    }
    _localCache.addTrainingSession(session);
  }

  @override
  Future<void> cancelSession(String sessionId) async {
    _localCache.cancelTrainingSession(sessionId);
  }
}
