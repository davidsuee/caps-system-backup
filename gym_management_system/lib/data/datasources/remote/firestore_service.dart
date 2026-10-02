import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../firebase_options.dart';
import '../../models/user_model.dart';
import '../../models/workout_plan_model.dart';
import '../../models/meal_plan_model.dart';
import '../../models/membership_model.dart';
import '../../models/progress_log_model.dart';
import '../../../domain/entities/user_entity.dart';
import 'firebase_auth_service.dart';

class FirestoreService {
  final FirebaseFirestore? _customDb;
  final Dio _dio;

  FirestoreService([FirebaseFirestore? db, Dio? dio])
      : _customDb = db,
        _dio = dio ?? Dio();

  FirebaseFirestore get _db => _customDb ?? FirebaseFirestore.instance;

  bool get _isWindowsDesktop => !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  // For REST endpoints over HTTP, always use the Web / Browser API key
  // because mobile API keys require Android/iOS client certificate headers
  String get _apiKey => DefaultFirebaseOptions.web.apiKey;
  String get _projectId => DefaultFirebaseOptions.currentPlatform.projectId;
  String get _restBaseUrl =>
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  // --- Firestore REST Serialization Helpers ---
  static Map<String, dynamic> encodeValue(dynamic val) {
    if (val == null) return {'nullValue': null};
    if (val is bool) return {'booleanValue': val};
    if (val is int) return {'integerValue': val.toString()};
    if (val is double) return {'doubleValue': val};
    if (val is num) return {'doubleValue': val.toDouble()};
    if (val is String) return {'stringValue': val};
    if (val is List) {
      if (val.isEmpty) return {'arrayValue': {}};
      return {'arrayValue': {'values': val.map(encodeValue).toList()}};
    }
    if (val is Map) {
      return {'mapValue': {'fields': encodeMap(Map<String, dynamic>.from(val))}};
    }
    return {'stringValue': val.toString()};
  }

  static Map<String, dynamic> encodeMap(Map<String, dynamic> map) {
    final res = <String, dynamic>{};
    for (final entry in map.entries) {
      res[entry.key] = encodeValue(entry.value);
    }
    return res;
  }

  static dynamic decodeValue(Map<String, dynamic>? val) {
    if (val == null) return null;
    if (val.containsKey('stringValue')) return val['stringValue']?.toString();
    if (val.containsKey('integerValue')) return int.tryParse(val['integerValue']?.toString() ?? '') ?? 0;
    if (val.containsKey('doubleValue')) return double.tryParse(val['doubleValue']?.toString() ?? '') ?? 0.0;
    if (val.containsKey('booleanValue')) return val['booleanValue'] == true;
    if (val.containsKey('nullValue')) return null;
    if (val.containsKey('arrayValue')) {
      final arr = val['arrayValue'];
      if (arr is Map && arr['values'] is List) {
        final values = arr['values'] as List;
        return values.map((e) => e is Map ? decodeValue(Map<String, dynamic>.from(e)) : e).toList();
      }
      return [];
    }
    if (val.containsKey('mapValue')) {
      final mv = val['mapValue'];
      if (mv is Map && mv['fields'] is Map) {
        return decodeMap(Map<String, dynamic>.from(mv['fields'] as Map));
      }
      return {};
    }
    if (val.containsKey('timestampValue')) return val['timestampValue']?.toString();
    return null;
  }

  static Map<String, dynamic> decodeMap(Map<String, dynamic>? fields) {
    final res = <String, dynamic>{};
    if (fields == null) return res;
    for (final entry in fields.entries) {
      if (entry.value is Map) {
        res[entry.key] = decodeValue(Map<String, dynamic>.from(entry.value as Map));
      } else {
        res[entry.key] = entry.value;
      }
    }
    return res;
  }

  // --- REST HTTP Methods ---
  Future<void> _restPatchDoc(String collection, String docId, Map<String, dynamic> data) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) {
      debugPrint('[Firestore REST] Cannot patch $collection with empty docId. Skipping request.');
      return;
    }
    final url = '$_restBaseUrl/$collection/$cleanDocId?key=$_apiKey';
    final payload = {'fields': encodeMap(data)};
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    final idToken = FirebaseAuthService.lastAuthenticatedUser?.idToken;
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    try {
      await _dio.patch(
        url,
        data: payload,
        options: Options(headers: headers),
      );
    } on DioException catch (dioErr) {
      debugPrint('[Firestore REST Error Response]: ${dioErr.response?.data}');
      // If token expired or rejected, retry without Authorization header
      if (headers.containsKey('Authorization') &&
          (dioErr.response?.statusCode == 400 || dioErr.response?.statusCode == 401)) {
        try {
          await _dio.patch(
            url,
            data: payload,
            options: Options(headers: {'Content-Type': 'application/json'}),
          );
          return;
        } catch (_) {}
      }
      debugPrint('[Firestore REST] Error patching $collection/$cleanDocId: $dioErr');
      rethrow;
    } catch (e) {
      debugPrint('[Firestore REST] Unexpected error patching $collection/$cleanDocId: $e');
      rethrow;
    }
  }

  Future<void> _restDeleteDoc(String collection, String docId) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;
    final url = '$_restBaseUrl/$collection/$cleanDocId?key=$_apiKey';
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    final idToken = FirebaseAuthService.lastAuthenticatedUser?.idToken;
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    try {
      await _dio.delete(url, options: Options(headers: headers));
    } catch (e) {
      debugPrint('[Firestore REST] Error deleting $collection/$cleanDocId: $e');
    }
  }

  Future<Map<String, dynamic>?> _restGetDoc(String collection, String docId) async {
    final url = '$_restBaseUrl/$collection/$docId?key=$_apiKey';
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    final idToken = FirebaseAuthService.lastAuthenticatedUser?.idToken;
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    try {
      final resp = await _dio.get(url, options: Options(headers: headers));
      final data = resp.data as Map<String, dynamic>;
      final fields = data['fields'] as Map<String, dynamic>?;
      if (fields == null) return null;
      return decodeMap(fields);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      if (headers.containsKey('Authorization') &&
          (e.response?.statusCode == 400 || e.response?.statusCode == 401)) {
        try {
          final resp = await _dio.get(url, options: Options(headers: {'Content-Type': 'application/json'}));
          final data = resp.data as Map<String, dynamic>;
          final fields = data['fields'] as Map<String, dynamic>?;
          if (fields == null) return null;
          return decodeMap(fields);
        } catch (_) {}
      }
      debugPrint('[Firestore REST] Error getting $collection/$docId: $e');
      return null;
    } catch (e) {
      debugPrint('[Firestore REST] Unexpected error getting $collection/$docId: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _restGetCollection(String collection) async {
    final url = '$_restBaseUrl/$collection?key=$_apiKey';
    final headers = <String, dynamic>{'Content-Type': 'application/json'};
    final idToken = FirebaseAuthService.lastAuthenticatedUser?.idToken;
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }
    try {
      final resp = await _dio.get(url, options: Options(headers: headers));
      final data = resp.data as Map<String, dynamic>;
      final documents = data['documents'] as List?;
      if (documents == null) return [];

      final list = <Map<String, dynamic>>[];
      for (final doc in documents) {
        final docMap = doc as Map<String, dynamic>;
        final name = docMap['name'] as String? ?? '';
        final id = name.split('/').last;
        final fields = docMap['fields'] as Map<String, dynamic>? ?? {};
        final decoded = decodeMap(fields);
        decoded['id'] = id;
        list.add(decoded);
      }
      return list;
    } on DioException catch (e) {
      debugPrint('[Firestore REST Get Error Response]: ${e.response?.data}');
      if (e.response?.statusCode == 404) return [];
      if (headers.containsKey('Authorization') &&
          (e.response?.statusCode == 400 || e.response?.statusCode == 401)) {
        try {
          final resp = await _dio.get(url, options: Options(headers: {'Content-Type': 'application/json'}));
          final data = resp.data as Map<String, dynamic>;
          final documents = data['documents'] as List?;
          if (documents == null) return [];

          final list = <Map<String, dynamic>>[];
          for (final doc in documents) {
            final docMap = doc as Map<String, dynamic>;
            final name = docMap['name'] as String? ?? '';
            final id = name.split('/').last;
            final fields = docMap['fields'] as Map<String, dynamic>? ?? {};
            final decoded = decodeMap(fields);
            decoded['id'] = id;
            list.add(decoded);
          }
          return list;
        } catch (_) {}
      }
      debugPrint('[Firestore REST] Error getting collection $collection: $e');
      return [];
    } catch (e) {
      debugPrint('[Firestore REST] Unexpected error getting collection $collection: $e');
      return [];
    }
  }

  // --- USERS ---
  Future<void> saveUser(UserModel user) async {
    if (_isWindowsDesktop) {
      await _restPatchDoc('users', user.id, user.toJson());
      return;
    }
    try {
      await _db.collection('users').doc(user.id).set(user.toJson(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[Firestore] Native saveUser failed: $e. Falling back to REST.');
      await _restPatchDoc('users', user.id, user.toJson());
    }
  }

  Future<void> deleteUser(String uid) async {
    if (_isWindowsDesktop) {
      await _restDeleteDoc('users', uid);
      return;
    }
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('[Firestore] Native deleteUser failed: $e. Falling back to REST.');
      await _restDeleteDoc('users', uid);
    }
  }

  Future<UserModel?> getUser(String uid) async {
    if (_isWindowsDesktop) {
      final data = await _restGetDoc('users', uid);
      if (data == null) return null;
      return UserModel.fromJson(data, uid);
    }
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return UserModel.fromJson(data, doc.id);
    } catch (e) {
      debugPrint('[Firestore] Native getUser failed: $e. Falling back to REST.');
      final data = await _restGetDoc('users', uid);
      if (data == null) return null;
      return UserModel.fromJson(data, uid);
    }
  }

  Future<List<UserModel>> getAllUsers() async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('users');
      return docs.map((d) => UserModel.fromJson(d, d['id'] as String? ?? '')).toList();
    }
    try {
      final query = await _db.collection('users').get();
      return query.docs.map((d) => UserModel.fromJson(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('[Firestore] Native getAllUsers failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('users');
      return docs.map((d) => UserModel.fromJson(d, d['id'] as String? ?? '')).toList();
    }
  }

  Future<List<UserModel>> getUsersByRole(UserRole role) async {
    final all = await getAllUsers();
    return all.where((u) => u.role == role).toList();
  }

  // --- WORKOUT PLANS ---
  Future<void> saveWorkoutPlan(WorkoutPlanModel plan) async {
    final docId = plan.id.trim().isNotEmpty
        ? plan.id.trim()
        : 'workout_${plan.userId.isNotEmpty ? plan.userId : "gen"}_${DateTime.now().millisecondsSinceEpoch}';
    final toSave = plan.id == docId ? plan : plan.copyWith(id: docId);
    if (_isWindowsDesktop) {
      await _restPatchDoc('workout_plans', docId, toSave.toJson());
      return;
    }
    try {
      await _db.collection('workout_plans').doc(docId).set(toSave.toJson());
    } catch (e) {
      debugPrint('[Firestore] Native saveWorkoutPlan failed: $e. Falling back to REST.');
      await _restPatchDoc('workout_plans', docId, toSave.toJson());
    }
  }

  Future<WorkoutPlanModel?> getLatestWorkoutPlan(String userId) async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('workout_plans');
      final userPlans = docs
          .where((d) => d['userId'] == userId)
          .map((d) => WorkoutPlanModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      if (userPlans.isEmpty) return null;
      userPlans.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return userPlans.first;
    }
    try {
      final query = await _db
          .collection('workout_plans')
          .where('userId', isEqualTo: userId)
          .get();

      if (query.docs.isEmpty) return null;
      final userPlans = query.docs
          .map((d) => WorkoutPlanModel.fromJson(d.data(), d.id))
          .toList();
      userPlans.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return userPlans.first;
    } catch (e) {
      debugPrint('[Firestore] Native getLatestWorkoutPlan failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('workout_plans');
      final userPlans = docs
          .where((d) => d['userId'] == userId)
          .map((d) => WorkoutPlanModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      if (userPlans.isEmpty) return null;
      userPlans.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return userPlans.first;
    }
  }

  Future<List<WorkoutPlanModel>> getAllWorkoutPlans() async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('workout_plans');
      return docs.map((d) => WorkoutPlanModel.fromJson(d, d['id'] as String? ?? '')).toList();
    }
    try {
      final query = await _db.collection('workout_plans').get();
      return query.docs.map((d) => WorkoutPlanModel.fromJson(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('[Firestore] Native getAllWorkoutPlans failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('workout_plans');
      return docs.map((d) => WorkoutPlanModel.fromJson(d, d['id'] as String? ?? '')).toList();
    }
  }

  // --- MEAL PLANS ---
  Future<void> saveMealPlan(MealPlanModel plan) async {
    final docId = plan.id.trim().isNotEmpty
        ? plan.id.trim()
        : 'meal_${plan.userId.isNotEmpty ? plan.userId : "gen"}_${DateTime.now().millisecondsSinceEpoch}';
    final toSave = plan.id == docId ? plan : plan.copyWith(id: docId);
    if (_isWindowsDesktop) {
      await _restPatchDoc('meal_plans', docId, toSave.toJson());
      return;
    }
    try {
      await _db.collection('meal_plans').doc(docId).set(toSave.toJson());
    } catch (e) {
      debugPrint('[Firestore] Native saveMealPlan failed: $e. Falling back to REST.');
      await _restPatchDoc('meal_plans', docId, toSave.toJson());
    }
  }

  Future<MealPlanModel?> getLatestMealPlan(String userId) async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('meal_plans');
      final userPlans = docs
          .where((d) => d['userId'] == userId)
          .map((d) => MealPlanModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      if (userPlans.isEmpty) return null;
      userPlans.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return userPlans.first;
    }
    try {
      final query = await _db
          .collection('meal_plans')
          .where('userId', isEqualTo: userId)
          .get();

      if (query.docs.isEmpty) return null;
      final userPlans = query.docs
          .map((d) => MealPlanModel.fromJson(d.data(), d.id))
          .toList();
      userPlans.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return userPlans.first;
    } catch (e) {
      debugPrint('[Firestore] Native getLatestMealPlan failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('meal_plans');
      final userPlans = docs
          .where((d) => d['userId'] == userId)
          .map((d) => MealPlanModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      if (userPlans.isEmpty) return null;
      userPlans.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return userPlans.first;
    }
  }

  Future<List<MealPlanModel>> getAllMealPlans() async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('meal_plans');
      return docs.map((d) => MealPlanModel.fromJson(d, d['id'] as String? ?? '')).toList();
    }
    try {
      final query = await _db.collection('meal_plans').get();
      return query.docs.map((d) => MealPlanModel.fromJson(d.data(), d.id)).toList();
    } catch (e) {
      debugPrint('[Firestore] Native getAllMealPlans failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('meal_plans');
      return docs.map((d) => MealPlanModel.fromJson(d, d['id'] as String? ?? '')).toList();
    }
  }

  // --- MEMBERSHIPS ---
  List<MembershipModel> _deduplicateMemberships(List<MembershipModel> list) {
    final Map<String, MembershipModel> map = {};
    for (final m in list) {
      if (m.userId.isEmpty) continue;
      final existing = map[m.userId];
      if (existing == null) {
        map[m.userId] = m;
      } else {
        // ACTIVE status ALWAYS takes priority over pending or expired!
        if (existing.isActive && !m.isActive) {
          // Keep existing active
        } else if (!existing.isActive && m.isActive) {
          map[m.userId] = m;
        } else if (m.isPending && !existing.isActive && !existing.isPending) {
          map[m.userId] = m;
        } else if (m.startDate.isAfter(existing.startDate)) {
          map[m.userId] = m;
        }
      }
    }
    return map.values.toList();
  }

  Future<void> saveMembership(MembershipModel membership) async {
    // Key by userId so each user has an authoritative lifecycle record in Firestore
    final docId = membership.userId.trim().isNotEmpty
        ? membership.userId.trim()
        : (membership.id.trim().isNotEmpty
            ? membership.id.trim()
            : 'mem_${DateTime.now().millisecondsSinceEpoch}');
    final toSave = MembershipModel(
      id: docId,
      userId: membership.userId,
      planName: membership.planName,
      price: membership.price,
      startDate: membership.startDate,
      endDate: membership.endDate,
      status: membership.status,
    );
    if (_isWindowsDesktop) {
      await _restPatchDoc('memberships', docId, toSave.toJson());
      if (membership.id.isNotEmpty && membership.id != docId) {
        await _restPatchDoc('memberships', membership.id, toSave.toJson());
      }
      return;
    }
    try {
      await _db.collection('memberships').doc(docId).set(toSave.toJson());
      if (membership.id.isNotEmpty && membership.id != docId) {
        await _db.collection('memberships').doc(membership.id).set(toSave.toJson());
      }
    } catch (e) {
      debugPrint('[Firestore] Native saveMembership failed: $e. Falling back to REST.');
      await _restPatchDoc('memberships', docId, toSave.toJson());
      if (membership.id.isNotEmpty && membership.id != docId) {
        await _restPatchDoc('memberships', membership.id, toSave.toJson());
      }
    }
  }

  Future<MembershipModel?> getUserMembership(String userId) async {
    if (userId.trim().isEmpty) return null;
    if (_isWindowsDesktop) {
      // First try direct document
      final singleDoc = await _restGetDoc('memberships', userId);
      if (singleDoc != null) {
        return MembershipModel.fromJson(singleDoc, userId);
      }
      final docs = await _restGetCollection('memberships');
      final list = docs
          .where((d) => d['userId'] == userId)
          .map((d) => MembershipModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      if (list.isEmpty) return null;
      final dedup = _deduplicateMemberships(list);
      return dedup.isNotEmpty ? dedup.first : null;
    }
    try {
      // 1. Try direct doc(userId)
      final docSnap = await _db.collection('memberships').doc(userId).get();
      final data = docSnap.data();
      if (docSnap.exists && data != null) {
        return MembershipModel.fromJson(data, docSnap.id);
      }

      // 2. Query by userId for legacy records
      final query = await _db
          .collection('memberships')
          .where('userId', isEqualTo: userId)
          .get();

      if (query.docs.isEmpty) return null;
      final list = query.docs
          .map((d) => MembershipModel.fromJson(d.data(), d.id))
          .toList();
      final dedup = _deduplicateMemberships(list);
      return dedup.isNotEmpty ? dedup.first : null;
    } catch (e) {
      debugPrint('[Firestore] Native getUserMembership failed: $e. Falling back to REST.');
      final singleDoc = await _restGetDoc('memberships', userId);
      if (singleDoc != null) {
        return MembershipModel.fromJson(singleDoc, userId);
      }
      final docs = await _restGetCollection('memberships');
      final list = docs
          .where((d) => d['userId'] == userId)
          .map((d) => MembershipModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      if (list.isEmpty) return null;
      final dedup = _deduplicateMemberships(list);
      return dedup.isNotEmpty ? dedup.first : null;
    }
  }

  Future<List<MembershipModel>> getAllMemberships() async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('memberships');
      final list = docs.map((d) => MembershipModel.fromJson(d, d['id'] as String? ?? '')).toList();
      return _deduplicateMemberships(list);
    }
    try {
      final query = await _db.collection('memberships').get();
      final list = query.docs.map((d) => MembershipModel.fromJson(d.data(), d.id)).toList();
      return _deduplicateMemberships(list);
    } catch (e) {
      debugPrint('[Firestore] Native getAllMemberships failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('memberships');
      final list = docs.map((d) => MembershipModel.fromJson(d, d['id'] as String? ?? '')).toList();
      return _deduplicateMemberships(list);
    }
  }

  // --- ATTENDANCE ---
  Future<void> logAttendance(AttendanceModel attendance) async {
    final docId = attendance.id.trim().isNotEmpty
        ? attendance.id.trim()
        : 'att_${attendance.userId.isNotEmpty ? attendance.userId : "gen"}_${DateTime.now().millisecondsSinceEpoch}';
    final toSave = attendance.id == docId
        ? attendance
        : AttendanceModel(
            id: docId,
            userId: attendance.userId,
            checkInTime: attendance.checkInTime,
            checkOutTime: attendance.checkOutTime,
          );
    if (_isWindowsDesktop) {
      await _restPatchDoc('attendance', docId, toSave.toJson());
      return;
    }
    try {
      await _db.collection('attendance').doc(docId).set(toSave.toJson());
    } catch (e) {
      debugPrint('[Firestore] Native logAttendance failed: $e. Falling back to REST.');
      await _restPatchDoc('attendance', docId, toSave.toJson());
    }
  }

  Future<List<AttendanceModel>> getAttendanceHistory(String userId) async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('attendance');
      final list = docs
          .where((d) => d['userId'] == userId)
          .map((d) => AttendanceModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list.take(30).toList();
    }
    try {
      final query = await _db
          .collection('attendance')
          .where('userId', isEqualTo: userId)
          .get();

      final list = query.docs.map((d) => AttendanceModel.fromJson(d.data(), d.id)).toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list.take(30).toList();
    } catch (e) {
      debugPrint('[Firestore] Native getAttendanceHistory failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('attendance');
      final list = docs
          .where((d) => d['userId'] == userId)
          .map((d) => AttendanceModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list.take(30).toList();
    }
  }

  Future<List<AttendanceModel>> getAllAttendance() async {
    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('attendance');
      final list = docs.map((d) => AttendanceModel.fromJson(d, d['id'] as String? ?? '')).toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list.take(100).toList();
    }
    try {
      final query = await _db.collection('attendance').get();
      final list = query.docs.map((d) => AttendanceModel.fromJson(d.data(), d.id)).toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list.take(100).toList();
    } catch (e) {
      debugPrint('[Firestore] Native getAllAttendance failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('attendance');
      final list = docs.map((d) => AttendanceModel.fromJson(d, d['id'] as String? ?? '')).toList();
      list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
      return list.take(100).toList();
    }
  }

  Stream<List<AttendanceModel>> watchAllAttendance({Duration interval = const Duration(seconds: 4)}) async* {
    if (!_isWindowsDesktop) {
      try {
        yield* _db
            .collection('attendance')
            .snapshots()
            .map((snap) {
              final list = snap.docs.map((d) => AttendanceModel.fromJson(d.data(), d.id)).toList();
              list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
              return list;
            });
        return;
      } catch (e) {
        debugPrint('[Firestore] Native watchAllAttendance failed: $e. Falling back to polling stream.');
      }
    }

    // Windows Desktop REST Stream
    while (true) {
      try {
        final list = await getAllAttendance();
        yield list;
      } catch (_) {}
      await Future.delayed(interval);
    }
  }

  Stream<List<AttendanceModel>> watchUserAttendance(String userId, {Duration interval = const Duration(seconds: 4)}) async* {
    if (!_isWindowsDesktop) {
      try {
        yield* _db
            .collection('attendance')
            .where('userId', isEqualTo: userId)
            .snapshots()
            .map((snap) {
              final list = snap.docs.map((d) => AttendanceModel.fromJson(d.data(), d.id)).toList();
              list.sort((a, b) => b.checkInTime.compareTo(a.checkInTime));
              return list;
            });
        return;
      } catch (e) {
        debugPrint('[Firestore] Native watchUserAttendance failed: $e. Falling back to polling stream.');
      }
    }

    while (true) {
      try {
        final list = await getAttendanceHistory(userId);
        yield list;
      } catch (_) {}
      await Future.delayed(interval);
    }
  }

  // --- PROGRESS LOGS ---
  Future<void> addProgressLog(ProgressLogModel log) async {
    final docId = log.id.trim().isNotEmpty
        ? log.id.trim()
        : 'log_${log.userId.isNotEmpty ? log.userId : "gen"}_${DateTime.now().millisecondsSinceEpoch}';
    final toSave = log.id == docId
        ? log
        : ProgressLogModel(
            id: docId,
            userId: log.userId,
            date: log.date,
            weightKg: log.weightKg,
            bodyFatPercent: log.bodyFatPercent,
            notes: log.notes,
          );
    if (_isWindowsDesktop) {
      await _restPatchDoc('progress_logs', docId, toSave.toJson());
      return;
    }
    try {
      await _db.collection('progress_logs').doc(docId).set(toSave.toJson());
    } catch (e) {
      debugPrint('[Firestore] Native addProgressLog failed: $e. Falling back to REST.');
      await _restPatchDoc('progress_logs', docId, toSave.toJson());
    }
  }

  Future<List<ProgressLogModel>> getProgressLogs(String userId, [String? userEmail, String? userName]) async {
    final cleanId = userId.trim();
    final cleanEmail = userEmail?.trim();
    final cleanName = userName?.trim();

    bool matchesUser(String? uid) {
      if (uid == null || uid.isEmpty) return false;
      final lower = uid.toLowerCase();
      if (lower == cleanId.toLowerCase()) return true;
      if (cleanEmail != null && cleanEmail.isNotEmpty && lower == cleanEmail.toLowerCase()) return true;
      if (cleanName != null && cleanName.isNotEmpty && lower == cleanName.toLowerCase()) return true;
      return false;
    }

    if (_isWindowsDesktop) {
      final docs = await _restGetCollection('progress_logs');
      final list = docs
          .where((d) => matchesUser((d['userId'] ?? d['user_id'])?.toString()))
          .map((d) => ProgressLogModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    }

    try {
      final Map<String, ProgressLogModel> resultMap = {};

      // 1. Query by userId
      final query1 = await _db
          .collection('progress_logs')
          .where('userId', isEqualTo: cleanId)
          .get();
      for (final doc in query1.docs) {
        resultMap[doc.id] = ProgressLogModel.fromJson(doc.data(), doc.id);
      }

      // 2. Query by userEmail
      if (cleanEmail != null && cleanEmail.isNotEmpty && cleanEmail.toLowerCase() != cleanId.toLowerCase()) {
        try {
          final query2 = await _db
              .collection('progress_logs')
              .where('userId', isEqualTo: cleanEmail)
              .get();
          for (final doc in query2.docs) {
            resultMap[doc.id] = ProgressLogModel.fromJson(doc.data(), doc.id);
          }
        } catch (_) {}
      }

      // 3. Fallback: if empty, query by user_id
      if (resultMap.isEmpty) {
        try {
          final query3 = await _db
              .collection('progress_logs')
              .where('user_id', isEqualTo: cleanId)
              .get();
          for (final doc in query3.docs) {
            resultMap[doc.id] = ProgressLogModel.fromJson(doc.data(), doc.id);
          }
        } catch (_) {}
      }

      // 4. Fallback: scan all progress_logs if still empty
      if (resultMap.isEmpty) {
        try {
          final allDocs = await _db.collection('progress_logs').get();
          for (final doc in allDocs.docs) {
            final data = doc.data();
            final uid = (data['userId'] ?? data['user_id'])?.toString();
            if (matchesUser(uid)) {
              resultMap[doc.id] = ProgressLogModel.fromJson(data, doc.id);
            }
          }
        } catch (_) {}
      }

      final list = resultMap.values.toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    } catch (e) {
      debugPrint('[Firestore] Native getProgressLogs failed: $e. Falling back to REST.');
      final docs = await _restGetCollection('progress_logs');
      final list = docs
          .where((d) => matchesUser((d['userId'] ?? d['user_id'])?.toString()))
          .map((d) => ProgressLogModel.fromJson(d, d['id'] as String? ?? ''))
          .toList();
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    }
  }
}
