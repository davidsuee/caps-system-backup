import '../entities/membership_entity.dart';

abstract class MembershipRepository {
  Future<MembershipEntity?> getUserMembership(String userId);
  Future<void> purchaseOrRenewMembership(MembershipEntity membership);
  Future<void> logCheckIn(String userId);
  Future<void> logCheckOut(String userId);
  Future<AttendanceEntity?> getActiveAttendance(String userId);
  Future<List<AttendanceEntity>> getAttendanceHistory(String userId);
  Stream<List<AttendanceEntity>> watchUserAttendance(String userId);
}

