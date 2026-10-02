class WalkInRecordModel {
  final String id;
  final String guestName;
  final String? contactNumber;
  final double amountPaid;
  final String paymentMethod;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final String? notes;
  final String recordedBy;

  const WalkInRecordModel({
    required this.id,
    required this.guestName,
    this.contactNumber,
    this.amountPaid = 150.0,
    this.paymentMethod = 'Cash at Counter',
    required this.checkInTime,
    this.checkOutTime,
    this.notes,
    this.recordedBy = 'Admin Desk',
  });

  bool get isActive {
    if (checkOutTime != null) return false;
    final now = DateTime.now();
    final closingTime = DateTime(checkInTime.year, checkInTime.month, checkInTime.day, 23, 0);
    if (now.isAfter(closingTime) || now.isAtSameMomentAs(closingTime)) {
      return false;
    }
    return true;
  }

  String get formattedDuration {
    final now = DateTime.now();
    final closingTime = DateTime(checkInTime.year, checkInTime.month, checkInTime.day, 23, 0);
    final end = checkOutTime ?? (now.isAfter(closingTime) ? closingTime : now);
    final diff = end.difference(checkInTime);
    if (diff.isNegative) return '0m';
    final hours = diff.inHours;
    final mins = diff.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  WalkInRecordModel copyWith({
    String? id,
    String? guestName,
    String? contactNumber,
    double? amountPaid,
    String? paymentMethod,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    String? notes,
    String? recordedBy,
  }) {
    return WalkInRecordModel(
      id: id ?? this.id,
      guestName: guestName ?? this.guestName,
      contactNumber: contactNumber ?? this.contactNumber,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      notes: notes ?? this.notes,
      recordedBy: recordedBy ?? this.recordedBy,
    );
  }

  factory WalkInRecordModel.fromJson(Map<String, dynamic> json, [String? id]) {
    return WalkInRecordModel(
      id: id ?? json['id']?.toString() ?? 'walkin_${DateTime.now().millisecondsSinceEpoch}',
      guestName: json['guestName']?.toString() ?? json['guest_name']?.toString() ?? 'Walk-In Guest',
      contactNumber: json['contactNumber']?.toString() ?? json['contact_number']?.toString(),
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ??
          (json['amount_paid'] as num?)?.toDouble() ??
          150.0,
      paymentMethod: json['paymentMethod']?.toString() ??
          json['payment_method']?.toString() ??
          'Cash at Counter',
      checkInTime: json['checkInTime'] != null
          ? DateTime.tryParse(json['checkInTime'].toString()) ?? DateTime.now()
          : DateTime.now(),
      checkOutTime: json['checkOutTime'] != null
          ? DateTime.tryParse(json['checkOutTime'].toString())
          : null,
      notes: json['notes']?.toString(),
      recordedBy: json['recordedBy']?.toString() ?? json['recorded_by']?.toString() ?? 'Admin Desk',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'guestName': guestName,
      'contactNumber': contactNumber,
      'amountPaid': amountPaid,
      'paymentMethod': paymentMethod,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'notes': notes,
      'recordedBy': recordedBy,
    };
  }
}
