class FacilityEntity {
  final String id;
  final String name;
  final String description;
  final int capacity;
  final int currentOccupancy;
  final String status; // 'open', 'cleaning', 'closed', 'maintenance'
  final String operatingHours;
  final String? iconName;

  const FacilityEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.capacity,
    this.currentOccupancy = 0,
    this.status = 'open',
    this.operatingHours = '6:00 AM - 10:00 PM',
    this.iconName,
  });

  bool get isOpen => status == 'open';
  bool get isCleaning => status == 'cleaning';
  bool get isClosed => status == 'closed';
  bool get isMaintenance => status == 'maintenance';

  double get occupancyRate =>
      capacity > 0 ? (currentOccupancy / capacity).clamp(0.0, 1.0) : 0.0;
  int get occupancyPercent => (occupancyRate * 100).round();

  FacilityEntity copyWith({
    String? id,
    String? name,
    String? description,
    int? capacity,
    int? currentOccupancy,
    String? status,
    String? operatingHours,
    String? iconName,
  }) {
    return FacilityEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      capacity: capacity ?? this.capacity,
      currentOccupancy: currentOccupancy ?? this.currentOccupancy,
      status: status ?? this.status,
      operatingHours: operatingHours ?? this.operatingHours,
      iconName: iconName ?? this.iconName,
    );
  }
}

class EquipmentEntity {
  final String id;
  final String facilityId;
  final String facilityName;
  final String name;
  final String category; // 'Cardio', 'Strength', 'Free Weights', 'Functional', 'Recovery'
  final String serialNumber;
  final String status; // 'operational', 'under_maintenance', 'out_of_order'
  final DateTime lastMaintained;
  final DateTime nextMaintenanceDate;
  final String? notes;

  const EquipmentEntity({
    required this.id,
    required this.facilityId,
    required this.facilityName,
    required this.name,
    required this.category,
    required this.serialNumber,
    this.status = 'operational',
    required this.lastMaintained,
    required this.nextMaintenanceDate,
    this.notes,
  });

  bool get isOperational => status == 'operational';
  bool get isUnderMaintenance => status == 'under_maintenance';
  bool get isOutOfOrder => status == 'out_of_order';

  EquipmentEntity copyWith({
    String? id,
    String? facilityId,
    String? facilityName,
    String? name,
    String? category,
    String? serialNumber,
    String? status,
    DateTime? lastMaintained,
    DateTime? nextMaintenanceDate,
    String? notes,
  }) {
    return EquipmentEntity(
      id: id ?? this.id,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      name: name ?? this.name,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      status: status ?? this.status,
      lastMaintained: lastMaintained ?? this.lastMaintained,
      nextMaintenanceDate: nextMaintenanceDate ?? this.nextMaintenanceDate,
      notes: notes ?? this.notes,
    );
  }
}
