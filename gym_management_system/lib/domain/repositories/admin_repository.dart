import '../../data/models/user_model.dart';
import '../../data/models/membership_model.dart';
import '../entities/trainer_assignment_entity.dart';

class AdminKpiData {
  final double monthlyRevenue;
  final int activeMembersCount;
  final int todayCheckInsCount;
  final double retentionRate;

  const AdminKpiData({
    required this.monthlyRevenue,
    required this.activeMembersCount,
    required this.todayCheckInsCount,
    required this.retentionRate,
  });
}

abstract class AdminRepository {
  Future<List<UserModel>> getAllMembers();
  Future<List<UserModel>> getAllCoaches();
  Future<List<MembershipModel>> getAllMemberships();
  Future<List<AttendanceModel>> getAllAttendance();
  Future<AdminKpiData> getKpiMetrics();
  Future<void> recordPayment({
    required String userId,
    required String planName,
    required double amount,
    required int durationDays,
  });
  Future<void> sendExpirationNotice({
    required String userId,
    required String title,
    required String message,
  });
  Future<void> approvePendingMembership(MembershipModel membership);
  Future<void> rejectPendingMembership({required String membershipId, required String userId});
  Future<AssignmentOptimizationResult> runTrainerAssignmentOptimization();
  Future<void> assignMemberToCoach({required String memberId, required String coachId});
  Future<void> updateCoachCapacity({required String coachId, required int maxClients});
  Future<void> logMemberCheckIn(String userId);
  Future<void> logMemberCheckOut(String userId);
}
