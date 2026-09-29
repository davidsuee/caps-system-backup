class AssignmentMatch {
  final String memberId;
  final String memberName;
  final String memberGoal;
  final String coachId;
  final String coachName;
  final String coachSpecialization;
  final int matchScore;
  final String matchReason;

  const AssignmentMatch({
    required this.memberId,
    required this.memberName,
    required this.memberGoal,
    required this.coachId,
    required this.coachName,
    required this.coachSpecialization,
    required this.matchScore,
    required this.matchReason,
  });
}

class AssignmentOptimizationResult {
  final int totalEvaluated;
  final int newlyAssignedCount;
  final List<AssignmentMatch> matches;
  final DateTime executedAt;

  const AssignmentOptimizationResult({
    required this.totalEvaluated,
    required this.newlyAssignedCount,
    required this.matches,
    required this.executedAt,
  });
}
