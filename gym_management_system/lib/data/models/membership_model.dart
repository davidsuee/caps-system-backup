import '../../domain/entities/membership_entity.dart';

class MembershipModel extends MembershipEntity {
  const MembershipModel({
    required super.id,
    required super.userId,
    required super.planName,
    required super.price,
    required super.startDate,
    required super.endDate,
    required super.status,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final planId = (id != null && id.isNotEmpty)
        ? id
        : (json['id'] != null && json['id'].toString().isNotEmpty)
            ? json['id'].toString()
            : 'mem_${DateTime.now().millisecondsSinceEpoch}';

    return MembershipModel(
      id: planId,
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      planName: (json['planName'] ?? json['plan_type'] ?? 'Monthly Standard').toString(),
      price: double.tryParse((json['price'] ?? json['amount_paid'] ?? 49.99).toString()) ?? 49.99,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'].toString()) ?? DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      status: json['status'] == 'active'
          ? MembershipStatus.active
          : (json['status'] == 'expired' ? MembershipStatus.expired : MembershipStatus.pending),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'planName': planName,
      'price': price,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'status': status.name,
    };
  }
}

class AttendanceModel extends AttendanceEntity {
  const AttendanceModel({
    required super.id,
    required super.userId,
    required super.checkInTime,
    super.checkOutTime,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final attId = (id != null && id.isNotEmpty)
        ? id
        : (json['id'] != null && json['id'].toString().isNotEmpty)
            ? json['id'].toString()
            : 'att_${DateTime.now().millisecondsSinceEpoch}';

    return AttendanceModel(
      id: attId,
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
    };
  }
}
