import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../config/env.dart';
import '../../domain/entities/membership_entity.dart';
import '../../domain/repositories/membership_repository.dart';
import '../models/membership_model.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  static final StreamController<AttendanceModel> _attendanceBroadcast =
      StreamController<AttendanceModel>.broadcast();
  static Stream<AttendanceModel> get attendanceStream => _attendanceBroadcast.stream;

  MembershipRepositoryImpl({
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  @override
  Future<MembershipEntity?> getUserMembership(String userId) async {
    if (Env.useFirebase) {
      try {
        final mem = await _firestore.getUserMembership(userId);
        if (mem != null) {
          _localCache.saveMembership(mem);
          return mem;
        }
      } catch (e) {
        debugPrint('[MembershipRepo] Firebase getUserMembership error: $e');
      }
    }
    return _localCache.getMembership(userId);
  }

  @override
  Future<void> purchaseOrRenewMembership(MembershipEntity membership) async {
    final model = membership is MembershipModel
        ? membership
        : MembershipModel(
            id: membership.id,
            userId: membership.userId,
            planName: membership.planName,
            price: membership.price,
            startDate: membership.startDate,
            endDate: membership.endDate,
            status: membership.status,
          );

    _localCache.saveMembership(model);
    if (Env.useFirebase) {
      try {
        await _firestore.saveMembership(model);
      } catch (e) {
        debugPrint('[MembershipRepo] Firebase saveMembership error: $e');
      }
    }
  }

  @override
  Future<void> logCheckIn(String userId) async {
    final att = AttendanceModel(
      id: const Uuid().v4(),
      userId: userId,
      checkInTime: DateTime.now(),
    );

    // 1. Immediately update Local Cache & SharedPreferences
    _localCache.addAttendance(att);
    _attendanceBroadcast.add(att);

    // 2. Persist to Firebase Firestore
    if (Env.useFirebase) {
      try {
        await _firestore.logAttendance(att);
        debugPrint('[MembershipRepo] Check-In successfully saved to Firebase Firestore: ${att.id}');
      } catch (e) {
        debugPrint('[MembershipRepo] Firebase logAttendance (Check-In) error: $e');
      }
    }
  }

  @override
  Future<void> logCheckOut(String userId) async {
    AttendanceModel? active = _localCache.getActiveAttendance(userId);
    if (active == null) {
      final history = await getAttendanceHistory(userId);
      final candidate = history.where((a) => a.checkOutTime == null).firstOrNull;
      if (candidate != null) {
        active = AttendanceModel(
          id: candidate.id,
          userId: candidate.userId,
          checkInTime: candidate.checkInTime,
        );
      }
    }

    if (active != null) {
      final updated = AttendanceModel(
        id: active.id,
        userId: active.userId,
        checkInTime: active.checkInTime,
        checkOutTime: DateTime.now(),
      );

      // 1. Immediately update Local Cache & SharedPreferences
      _localCache.updateAttendance(updated);
      _attendanceBroadcast.add(updated);

      // 2. Persist to Firebase Firestore
      if (Env.useFirebase) {
        try {
          await _firestore.logAttendance(updated);
          debugPrint('[MembershipRepo] Check-Out successfully saved to Firebase Firestore: ${updated.id}');
        } catch (e) {
          debugPrint('[MembershipRepo] Firebase logAttendance (Check-Out) error: $e');
        }
      }
    }
  }

  @override
  Future<AttendanceEntity?> getActiveAttendance(String userId) async {
    final active = _localCache.getActiveAttendance(userId);
    if (active != null) return active;
    final history = await getAttendanceHistory(userId);
    return history.where((a) => a.checkOutTime == null).firstOrNull;
  }

  @override
  Future<List<AttendanceEntity>> getAttendanceHistory(String userId) async {
    if (Env.useFirebase) {
      try {
        final list = await _firestore.getAttendanceHistory(userId);
        if (list.isNotEmpty) {
          _localCache.saveAttendanceList(list);
          return _localCache.getAttendance(userId);
        }
      } catch (e) {
        debugPrint('[MembershipRepo] Firebase getAttendanceHistory error: $e');
      }
    }
    return _localCache.getAttendance(userId);
  }

  @override
  Stream<List<AttendanceEntity>> watchUserAttendance(String userId) async* {
    // Initial emit from local cache for instant UI rendering
    yield _localCache.getAttendance(userId);

    if (Env.useFirebase) {
      // Stream from Firestore real-time updates
      yield* _firestore.watchUserAttendance(userId).map((list) {
        if (list.isNotEmpty) {
          _localCache.saveAttendanceList(list);
        }
        return _localCache.getAttendance(userId);
      });
    } else {
      // Local broadcast stream
      yield* _attendanceBroadcast.stream
          .where((att) => att.userId == userId)
          .map((_) => _localCache.getAttendance(userId));
    }
  }
}
