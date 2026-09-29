import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../models/workout_plan_model.dart';
import '../../models/meal_plan_model.dart';
import '../../models/membership_model.dart';
import '../../models/progress_log_model.dart';
import '../../models/facility_model.dart';
import '../../../domain/entities/user_entity.dart';

class LocalCacheService {
  static final LocalCacheService _instance = LocalCacheService._internal();
  factory LocalCacheService() => _instance;

  static SharedPreferences? _prefs;
  static SharedPreferences? get prefs => _prefs;

  static Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _instance._loadFromPrefs();
    } catch (e) {
      debugPrint('[LocalCacheService] SharedPreferences init error: $e');
    }
  }

  void _loadFromPrefs() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;

      final curUserJson = prefs.getString('viscous_cached_current_user');
      if (curUserJson != null && curUserJson.isNotEmpty) {
        final decoded = jsonDecode(curUserJson);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          _currentUser = UserModel.fromJson(map, map['id']?.toString() ?? '');
        }
      }

      final memsJson = prefs.getString('viscous_cached_memberships');
      if (memsJson != null && memsJson.isNotEmpty) {
        final decoded = jsonDecode(memsJson);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final m = MembershipModel.fromJson(map, map['id']?.toString() ?? '');
              if (m.userId.isNotEmpty) {
                _memberships[m.userId] = m;
              }
            }
          }
        }
      }

      final usersJson = prefs.getString('viscous_cached_users');
      if (usersJson != null && usersJson.isNotEmpty) {
        final decodedUsers = jsonDecode(usersJson);
        if (decodedUsers is List) {
          for (final item in decodedUsers) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final u = UserModel.fromJson(map, map['id']?.toString() ?? '');
              if (u.email.isNotEmpty) {
                _users[u.email.toLowerCase().trim()] = u;
              }
              if (u.id.isNotEmpty) {
                _users[u.id] = u;
              }
            }
          }
        }
      }

      final attJson = prefs.getString('viscous_cached_attendance');
      if (attJson != null && attJson.isNotEmpty) {
        final decodedAtt = jsonDecode(attJson);
        if (decodedAtt is List) {
          _attendance.clear();
          for (final item in decodedAtt) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final a = AttendanceModel.fromJson(map, map['id']?.toString() ?? '');
              _attendance.add(a);
            }
          }
        }
      }

      final logsJson = prefs.getString('viscous_cached_progress_logs');
      if (logsJson != null && logsJson.isNotEmpty) {
        final decodedLogs = jsonDecode(logsJson);
        if (decodedLogs is List) {
          _progressLogs.clear();
          for (final item in decodedLogs) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final l = ProgressLogModel.fromJson(map, map['id']?.toString() ?? '');
              _progressLogs.add(l);
            }
          }
        }
      }

      final workoutsJson = prefs.getString('viscous_cached_workouts');
      if (workoutsJson != null && workoutsJson.isNotEmpty) {
        final decodedWorkouts = jsonDecode(workoutsJson);
        if (decodedWorkouts is List) {
          for (final item in decodedWorkouts) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final w = WorkoutPlanModel.fromJson(map, map['id']?.toString() ?? '');
              if (w.userId.isNotEmpty) {
                _activeWorkouts[w.userId] = w;
              }
            }
          }
        }
      }

      final mealsJson = prefs.getString('viscous_cached_meals');
      if (mealsJson != null && mealsJson.isNotEmpty) {
        final decodedMeals = jsonDecode(mealsJson);
        if (decodedMeals is List) {
          for (final item in decodedMeals) {
            if (item is Map) {
              final map = Map<String, dynamic>.from(item);
              final m = MealPlanModel.fromJson(map, map['id']?.toString() ?? '');
              if (m.userId.isNotEmpty) {
                _activeMeals[m.userId] = m;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error loading from prefs: $e');
    }
  }

  void _persistCurrentUser() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      if (_currentUser != null) {
        prefs.setString('viscous_cached_current_user', jsonEncode(_currentUser!.toJson()));
      } else {
        prefs.remove('viscous_cached_current_user');
      }
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting current user: $e');
    }
  }

  void _persistMemberships() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final mapList = _memberships.values.map((m) => m.toJson()).toList();
      prefs.setString('viscous_cached_memberships', jsonEncode(mapList));
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting memberships: $e');
    }
  }

  void _persistUsers() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final uniqueUsers = _users.values.toSet().toList();
      final mapList = uniqueUsers.map((u) => u.toJson()).toList();
      prefs.setString('viscous_cached_users', jsonEncode(mapList));
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting users: $e');
    }
  }

  void _persistAttendance() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final mapList = _attendance.map((a) => a.toJson()).toList();
      prefs.setString('viscous_cached_attendance', jsonEncode(mapList));
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting attendance: $e');
    }
  }

  void _persistProgressLogs() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final mapList = _progressLogs.map((p) => p.toJson()).toList();
      prefs.setString('viscous_cached_progress_logs', jsonEncode(mapList));
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting progress logs: $e');
    }
  }

  void _persistWorkouts() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final mapList = _activeWorkouts.values.map((w) => w.toJson()).toList();
      prefs.setString('viscous_cached_workouts', jsonEncode(mapList));
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting workouts: $e');
    }
  }

  void _persistMeals() {
    try {
      final prefs = _prefs;
      if (prefs == null) return;
      final mapList = _activeMeals.values.map((m) => m.toJson()).toList();
      prefs.setString('viscous_cached_meals', jsonEncode(mapList));
    } catch (e) {
      debugPrint('[LocalCacheService] Error persisting meals: $e');
    }
  }

  UserModel? _currentUser;
  final Map<String, UserModel> _users = {};
  final Map<String, WorkoutPlanModel> _activeWorkouts = {};
  final Map<String, MealPlanModel> _activeMeals = {};
  final Map<String, MembershipModel> _memberships = {};
  final List<AttendanceModel> _attendance = [];
  final List<ProgressLogModel> _progressLogs = [];
  final List<AppNotificationModel> _notifications = [];
  final List<TrainingSessionModel> _trainingSessions = [];
  final Map<String, FacilityModel> _facilities = {};
  final Map<String, EquipmentModel> _equipment = {};
  final Set<String> _deletedEquipmentIds = {};

  LocalCacheService._internal() {
    _seedInitialData();
  }

  void _seedInitialData() {
    final demoCoach = UserModel(
      id: 'coach_demo_01',
      name: 'Coach Marcus Vance',
      email: 'coach@gym.com',
      role: UserRole.coach,
      specialization: 'Strength & Conditioning',
      maxClients: 6,
      age: 32,
      heightCm: 182.0,
      weightKg: 85.0,
      gender: 'Male',
      fitnessGoal: 'Improve Endurance',
      activityLevel: 'Very Active',
      experienceLevel: 'Advanced',
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    );

    final coachElena = UserModel(
      id: 'coach_demo_02',
      name: 'Coach Elena Rostova',
      email: 'elena.coach@gym.com',
      role: UserRole.coach,
      specialization: 'Fat Loss & Functional HIIT',
      maxClients: 6,
      age: 28,
      heightCm: 165.0,
      weightKg: 55.0,
      gender: 'Female',
      fitnessGoal: 'Cardiovascular Health',
      activityLevel: 'Very Active',
      experienceLevel: 'Advanced',
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    );

    final coachDave = UserModel(
      id: 'coach_demo_03',
      name: 'Coach Dave Bautista',
      email: 'dave.coach@gym.com',
      role: UserRole.coach,
      specialization: 'Bodybuilding & Hypertrophy',
      maxClients: 6,
      age: 35,
      heightCm: 188.0,
      weightKg: 98.0,
      gender: 'Male',
      fitnessGoal: 'Muscle Hypertrophy',
      activityLevel: 'Very Active',
      experienceLevel: 'Advanced',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    );

    final demoAdmin = UserModel(
      id: 'admin_demo_01',
      name: 'Admin Sarah Connor',
      email: 'staff@gym.com',
      role: UserRole.admin,
      age: 29,
      heightCm: 168.0,
      weightKg: 58.0,
      gender: 'Female',
      fitnessGoal: 'General Fitness',
      activityLevel: 'Moderately Active',
      experienceLevel: 'Advanced',
      createdAt: DateTime.now().subtract(const Duration(days: 300)),
    );

    final member1 = UserModel(
      id: 'member_seed_01',
      name: 'Sarah Jenkins',
      email: 'sarah.j@example.com',
      role: UserRole.member,
      age: 26,
      fitnessGoal: 'Weight Loss',
      activityLevel: 'Lightly Active',
      experienceLevel: 'Beginner',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    );

    final member2 = UserModel(
      id: 'member_seed_02',
      name: 'Michael Chang',
      email: 'michael.c@example.com',
      role: UserRole.member,
      age: 31,
      fitnessGoal: 'Strength & Conditioning',
      activityLevel: 'Moderately Active',
      experienceLevel: 'Intermediate',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    );

    final member3 = UserModel(
      id: 'member_seed_03',
      name: 'Arnold Rivera',
      email: 'arnold.r@example.com',
      role: UserRole.member,
      age: 24,
      fitnessGoal: 'Muscle Gain',
      activityLevel: 'Very Active',
      experienceLevel: 'Intermediate',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );

    _users[demoCoach.email.toLowerCase()] = demoCoach;
    _users[demoCoach.id] = demoCoach;
    _users[coachElena.email.toLowerCase()] = coachElena;
    _users[coachElena.id] = coachElena;
    _users[coachDave.email.toLowerCase()] = coachDave;
    _users[coachDave.id] = coachDave;

    _users[demoAdmin.email.toLowerCase()] = demoAdmin;
    _users[demoAdmin.id] = demoAdmin;

    _users[member1.email.toLowerCase()] = member1;
    _users[member1.id] = member1;
    _users[member2.email.toLowerCase()] = member2;
    _users[member2.id] = member2;
    _users[member3.email.toLowerCase()] = member3;
    _users[member3.id] = member3;

    // Seed Facility Zones (ERD Table 10.0)
    final fac1 = FacilityModel(
      id: 'fac_cardio_01',
      name: 'Cardio Deck & Aerobics',
      description: 'High-performance commercial treadmills, rowers, and ellipticals',
      capacity: 30,
      currentOccupancy: 12,
      status: 'open',
      operatingHours: '6:00 AM - 10:00 PM',
      iconName: 'directions_run',
    );
    final fac2 = FacilityModel(
      id: 'fac_free_weights_01',
      name: 'Free Weights & Powerlifting Area',
      description: 'Olympic power racks, calibrated bumper plates, and dumbbell racks up to 50kg',
      capacity: 40,
      currentOccupancy: 26,
      status: 'open',
      operatingHours: '6:00 AM - 10:00 PM',
      iconName: 'fitness_center',
    );
    final fac3 = FacilityModel(
      id: 'fac_studio_01',
      name: 'Group Studio & Yoga Zone',
      description: 'Hardwood floor studio for group HIIT classes, mobility, and core conditioning',
      capacity: 25,
      currentOccupancy: 8,
      status: 'open',
      operatingHours: '7:00 AM - 9:00 PM',
      iconName: 'sports_gymnastics',
    );
    final fac4 = FacilityModel(
      id: 'fac_functional_01',
      name: 'Functional & Boxing Turf',
      description: 'Artificial turf sprint track, prowler sled, battle ropes, and heavy bags',
      capacity: 20,
      currentOccupancy: 5,
      status: 'open',
      operatingHours: '6:00 AM - 10:00 PM',
      iconName: 'sports_mma',
    );

    _facilities[fac1.id] = fac1;
    _facilities[fac2.id] = fac2;
    _facilities[fac3.id] = fac3;
    _facilities[fac4.id] = fac4;

    // Seed Equipment Inventory (ERD Table 11.0)
    final eq1 = EquipmentModel(
      id: 'eq_treadmill_01',
      facilityId: 'fac_cardio_01',
      facilityName: 'Cardio Deck & Aerobics',
      name: 'Commercial Treadmill',
      category: 'Cardio',
      serialNumber: 'VF-CD-001',
      status: 'operational',
      lastMaintained: DateTime.now().subtract(const Duration(days: 14)),
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 45)),
    );
    final eq3 = EquipmentModel(
      id: 'eq_squat_rack_01',
      facilityId: 'fac_free_weights_01',
      facilityName: 'Free Weights & Powerlifting Area',
      name: 'Heavy-Duty Olympic Power Rack',
      category: 'Strength',
      serialNumber: 'VF-FW-001',
      status: 'operational',
      lastMaintained: DateTime.now().subtract(const Duration(days: 30)),
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 60)),
    );
    final eq4 = EquipmentModel(
      id: 'eq_bench_01',
      facilityId: 'fac_free_weights_01',
      facilityName: 'Free Weights & Powerlifting Area',
      name: 'Olympic Flat Bench Press Station',
      category: 'Free Weights',
      serialNumber: 'VF-FW-002',
      status: 'operational',
      lastMaintained: DateTime.now().subtract(const Duration(days: 20)),
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 70)),
    );
    final eq5 = EquipmentModel(
      id: 'eq_cable_01',
      facilityId: 'fac_free_weights_01',
      facilityName: 'Free Weights & Powerlifting Area',
      name: 'Dual Adjustable Cable Crossover',
      category: 'Strength',
      serialNumber: 'VF-FW-003',
      status: 'operational',
      lastMaintained: DateTime.now().subtract(const Duration(days: 15)),
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 55)),
    );
    final eq6 = EquipmentModel(
      id: 'eq_rower_01',
      facilityId: 'fac_functional_01',
      facilityName: 'Functional & Boxing Turf',
      name: 'Concept2 Ergometer Rower',
      category: 'Functional',
      serialNumber: 'VF-FN-001',
      status: 'operational',
      lastMaintained: DateTime.now().subtract(const Duration(days: 25)),
      nextMaintenanceDate: DateTime.now().add(const Duration(days: 65)),
    );

    _equipment[eq1.id] = eq1;
    _equipment[eq3.id] = eq3;
    _equipment[eq4.id] = eq4;
    _equipment[eq5.id] = eq5;
    _equipment[eq6.id] = eq6;
    _ensureNewEquipmentSeeded();
  }

  UserModel? getCurrentUser() => _currentUser;
  void setCurrentUser(UserModel? user) {
    _currentUser = user;
    _persistCurrentUser();
  }

  UserModel? getUserByEmail(String email) => _users[email.toLowerCase().trim()];
  UserModel? getUserById(String id) => _users[id] ?? _users.values.where((u) => u.id == id).firstOrNull;
  List<UserModel> getAllUsers() {
    final Map<String, UserModel> map = {};
    for (final u in _users.values) {
      if (u.id.isNotEmpty) {
        map[u.id] = u;
      }
    }
    return map.values.toList();
  }
  List<UserModel> getUsersByRole(UserRole role) => getAllUsers().where((u) => u.role == role).toList();
  void saveUser(UserModel user) {
    _users[user.email.toLowerCase().trim()] = user;
    _users[user.id] = user;
    _persistUsers();
  }

  void saveUsers(List<UserModel> users) {
    for (final u in users) {
      _users[u.email.toLowerCase().trim()] = u;
      _users[u.id] = u;
    }
    _persistUsers();
  }

  WorkoutPlanModel? getWorkoutPlan(String userId) => _activeWorkouts[userId];
  void saveWorkoutPlan(WorkoutPlanModel plan) {
    _activeWorkouts[plan.userId] = plan;
    _persistWorkouts();
  }

  MealPlanModel? getMealPlan(String userId) => _activeMeals[userId];
  void saveMealPlan(MealPlanModel plan) {
    _activeMeals[plan.userId] = plan;
    _persistMeals();
  }

  MembershipModel? getMembership(String userId) => _memberships[userId];
  List<MembershipModel> getAllMemberships() => _memberships.values.toList();
  void saveMembership(MembershipModel membership) {
    _memberships[membership.userId] = membership;
    _persistMemberships();
  }

  void saveMemberships(List<MembershipModel> memberships) {
    for (final m in memberships) {
      if (m.userId.isNotEmpty) {
        _memberships[m.userId] = m;
      }
    }
    _persistMemberships();
  }

  void deleteMembership(String userId) {
    _memberships.remove(userId);
    _persistMemberships();
  }

  void deleteMembershipById(String id) {
    _memberships.removeWhere((_, m) => m.id == id);
    _persistMemberships();
  }

  List<AttendanceModel> getAttendance(String userId) => _attendance.where((a) => a.userId == userId).toList();
  List<AttendanceModel> getAllAttendance() => List.unmodifiable(_attendance);
  void addAttendance(AttendanceModel a) {
    _attendance.removeWhere((item) => item.id == a.id);
    _attendance.insert(0, a);
    _persistAttendance();
  }
  void logAttendance(AttendanceModel a) => addAttendance(a);
  AttendanceModel? getActiveAttendance(String userId) {
    for (final a in _attendance) {
      if (a.userId == userId && a.checkOutTime == null) return a;
    }
    return null;
  }
  void updateAttendance(AttendanceModel updated) {
    final index = _attendance.indexWhere((a) => a.id == updated.id);
    if (index != -1) {
      _attendance[index] = updated;
    } else {
      _attendance.insert(0, updated);
    }
    _persistAttendance();
  }

  void saveAttendanceList(List<AttendanceModel> list) {
    final Map<String, AttendanceModel> map = {};
    for (final a in _attendance) {
      map[a.id] = a;
    }
    for (final a in list) {
      final local = map[a.id];
      // If we already recorded a check-out locally, do NOT overwrite with null checkOutTime
      if (local != null && local.checkOutTime != null && a.checkOutTime == null) {
        continue;
      }
      map[a.id] = a;
    }
    final merged = map.values.toList();
    merged.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
    _attendance.clear();
    _attendance.addAll(merged);
    _persistAttendance();
  }

  List<ProgressLogModel> getProgressLogs(String userId, [String? userEmail, String? userName]) {
    final cleanId = userId.trim().toLowerCase();
    final cleanEmail = userEmail?.trim().toLowerCase();
    final cleanName = userName?.trim().toLowerCase();
    final results = _progressLogs.where((p) {
      final pUser = p.userId.trim().toLowerCase();
      if (pUser == cleanId) return true;
      if (cleanEmail != null && cleanEmail.isNotEmpty && pUser == cleanEmail) return true;
      if (cleanName != null && cleanName.isNotEmpty && pUser == cleanName) return true;
      return false;
    }).toList();
    results.sort((a, b) => a.date.compareTo(b.date));
    return results;
  }

  void addProgressLog(ProgressLogModel p) {
    final idx = _progressLogs.indexWhere((existing) => existing.id == p.id);
    if (idx >= 0) {
      _progressLogs[idx] = p;
    } else {
      _progressLogs.add(p);
    }
    _persistProgressLogs();
  }

  void saveProgressLogs(List<ProgressLogModel> logs) {
    for (final p in logs) {
      final idx = _progressLogs.indexWhere((existing) => existing.id == p.id);
      if (idx >= 0) {
        _progressLogs[idx] = p;
      } else {
        _progressLogs.add(p);
      }
    }
    _persistProgressLogs();
  }

  List<AppNotificationModel> getNotifications(String userId) =>
      _notifications.where((n) => n.userId == userId).toList();
  void addNotification(AppNotificationModel n) => _notifications.insert(0, n);
  void dismissNotification(String id) => _notifications.removeWhere((n) => n.id == id);

  List<TrainingSessionModel> getCoachSessions(String coachId) =>
      _trainingSessions.where((s) => s.coachId == coachId).toList();
  List<TrainingSessionModel> getMemberSessions(String memberId) =>
      _trainingSessions.where((s) => s.memberId == memberId).toList();
  List<TrainingSessionModel> getAllSessions() => List.unmodifiable(_trainingSessions);
  void addTrainingSession(TrainingSessionModel s) => _trainingSessions.insert(0, s);

  void approveWorkoutPlan(String userId, [String? notes]) {
    final existing = _activeWorkouts[userId];
    if (existing != null) {
      _activeWorkouts[userId] = WorkoutPlanModel(
        id: existing.id,
        userId: existing.userId,
        splitTitle: existing.splitTitle,
        confidenceScore: existing.confidenceScore,
        source: existing.source,
        summary: existing.summary,
        exercises: existing.exercises,
        generatedAt: existing.generatedAt,
        isCoachApproved: true,
        coachNotes: notes ?? 'Approved by Coach. Form & pacing look great!',
      );
      _persistWorkouts();
    }
  }

  void approveMealPlan(String userId, [String? notes]) {
    final existing = _activeMeals[userId];
    if (existing != null) {
      _activeMeals[userId] = MealPlanModel(
        id: existing.id,
        userId: existing.userId,
        source: existing.source,
        totalCalories: existing.totalCalories,
        targetCalories: existing.targetCalories,
        totalProtein: existing.totalProtein,
        targetProtein: existing.targetProtein,
        totalCarbs: existing.totalCarbs,
        targetCarbs: existing.targetCarbs,
        totalFat: existing.totalFat,
        targetFat: existing.targetFat,
        totalCost: existing.totalCost,
        budgetLimit: existing.budgetLimit,
        isFeasible: existing.isFeasible,
        solverMessage: existing.solverMessage,
        meals: existing.meals,
        generatedAt: existing.generatedAt,
        isCoachApproved: true,
        coachNotes: notes ?? 'Macronutrients reviewed and approved by Coach.',
      );
      _persistMeals();
    }
  }

  // Facility & Equipment Management (Tables 10.0 & 11.0)
  List<FacilityModel> getAllFacilities() {
    for (final key in _facilities.keys.toList()) {
      final f = _facilities[key]!;
      if (f.name.contains('Arena')) {
        _facilities[key] = FacilityModel.fromEntity(
          f.copyWith(name: f.name.replaceAll('Arena', 'Area')),
        );
      }
    }
    return _facilities.values.toList();
  }
  FacilityModel? getFacility(String id) => _facilities[id];
  void saveFacility(FacilityModel f) => _facilities[f.id] = f;

  List<EquipmentModel> getAllEquipment() {
    _equipment.remove('eq_treadmill_02');
    _equipment.remove('eq_stair_01');
    _ensureNewEquipmentSeeded();
    final tread = _equipment['eq_treadmill_01'];
    if (tread != null && tread.name != 'Commercial Treadmill') {
      _equipment['eq_treadmill_01'] = EquipmentModel.fromEntity(
        tread.copyWith(name: 'Commercial Treadmill'),
      );
    }
    for (final key in _equipment.keys.toList()) {
      final eq = _equipment[key]!;
      if (eq.facilityName.contains('Arena')) {
        _equipment[key] = EquipmentModel.fromEntity(
          eq.copyWith(facilityName: eq.facilityName.replaceAll('Arena', 'Area')),
        );
      }
    }
    return _equipment.values.toList();
  }
  EquipmentModel? getEquipment(String id) => _equipment[id];
  void saveEquipment(EquipmentModel e) => _equipment[e.id] = e;
  void deleteEquipment(String id) {
    _deletedEquipmentIds.add(id);
    _equipment.remove(id);
  }

  void _ensureNewEquipmentSeeded() {
    final newItems = [
      EquipmentModel(
        id: 'eq_machine_curl_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Machine Curl',
        category: 'Strength',
        serialNumber: 'VF-FW-004',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 8)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 60)),
      ),
      EquipmentModel(
        id: 'eq_pec_deck_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Peck Deck Fly Machine',
        category: 'Strength',
        serialNumber: 'VF-FW-005',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 12)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 65)),
      ),
      EquipmentModel(
        id: 'eq_calf_raise_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Calf Raises Machine',
        category: 'Strength',
        serialNumber: 'VF-FW-006',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 10)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 70)),
      ),
      EquipmentModel(
        id: 'eq_leg_press_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Leg Press Machine',
        category: 'Strength',
        serialNumber: 'VF-FW-007',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 5)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 75)),
      ),
      EquipmentModel(
        id: 'eq_lat_pulldown_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Lat Pull Down Machine',
        category: 'Strength',
        serialNumber: 'VF-FW-008',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 18)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 50)),
      ),
      EquipmentModel(
        id: 'eq_row_machine_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Row Machine',
        category: 'Strength',
        serialNumber: 'VF-FW-009',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 15)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 55)),
      ),
      EquipmentModel(
        id: 'eq_cable_machine_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Cable Machine',
        category: 'Strength',
        serialNumber: 'VF-FW-010',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 7)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 80)),
      ),
      EquipmentModel(
        id: 'eq_squat_rack_station_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Squat Rack',
        category: 'Strength',
        serialNumber: 'VF-FW-011',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 22)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 60)),
      ),
      EquipmentModel(
        id: 'eq_dumbbell_rack_01',
        facilityId: 'fac_free_weights_01',
        facilityName: 'Free Weights & Powerlifting Area',
        name: 'Dumbbell Rack',
        category: 'Free Weights',
        serialNumber: 'VF-FW-012',
        status: 'operational',
        lastMaintained: DateTime.now().subtract(const Duration(days: 10)),
        nextMaintenanceDate: DateTime.now().add(const Duration(days: 90)),
        notes: 'Heavy-duty 3-tier dumbbell rack (2.5kg - 50kg pairs)',
      ),
    ];
    for (final item in newItems) {
      if (!_deletedEquipmentIds.contains(item.id) && !_equipment.containsKey(item.id)) {
        _equipment[item.id] = item;
      }
    }
  }
}

class AppNotificationModel {
  final String id;
  final String userId;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const AppNotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });
}

class TrainingSessionModel {
  final String id;
  final String coachId;
  final String coachName;
  final String memberId;
  final String memberName;
  final DateTime dateTime;
  final String focus;
  final String status;

  const TrainingSessionModel({
    required this.id,
    required this.coachId,
    required this.coachName,
    required this.memberId,
    required this.memberName,
    required this.dateTime,
    required this.focus,
    this.status = 'confirmed',
  });
}
