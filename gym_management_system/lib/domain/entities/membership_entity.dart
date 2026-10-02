enum MembershipStatus {
  active,
  expired,
  pending;

  String get displayName {
    switch (this) {
      case MembershipStatus.active:
        return 'Active';
      case MembershipStatus.expired:
        return 'Expired';
      case MembershipStatus.pending:
        return 'Pending';
    }
  }
}

class MembershipEntity {
  final String id;
  final String userId;
  final String planName; // Monthly Standard, VIP All-Access, Student Pass
  final double price;
  final DateTime startDate;
  final DateTime endDate;
  final MembershipStatus status;

  const MembershipEntity({
    required this.id,
    required this.userId,
    required this.planName,
    required this.price,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  bool get isValid => status == MembershipStatus.active && endDate.isAfter(DateTime.now());
  bool get isActive => isValid;
  bool get isPending => status == MembershipStatus.pending;
  bool get isExpired => status == MembershipStatus.expired || (status == MembershipStatus.active && endDate.isBefore(DateTime.now()));

  int get remainingDays {
    final diff = endDate.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class AttendanceEntity {
  final String id;
  final String userId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? guestName;
  final bool isWalkIn;
  final double? amountPaid;
  final String? contactNumber;
  final String? paymentMethod;
  final String? notes;

  const AttendanceEntity({
    required this.id,
    required this.userId,
    required this.checkInTime,
    this.checkOutTime,
    this.guestName,
    this.isWalkIn = false,
    this.amountPaid,
    this.contactNumber,
    this.paymentMethod,
    this.notes,
  });

  bool get isCompleted => checkOutTime != null;
  bool get isInProgress => checkOutTime == null;
  Duration? get sessionDuration => checkOutTime?.difference(checkInTime);
  String get status => isCompleted ? 'completed' : 'present';
}
