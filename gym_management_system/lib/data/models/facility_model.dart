import '../../domain/entities/facility_entity.dart';

class FacilityModel extends FacilityEntity {
  const FacilityModel({
    required super.id,
    required super.name,
    required super.description,
    required super.capacity,
    super.currentOccupancy,
    super.status,
    super.operatingHours,
    super.iconName,
  });

  factory FacilityModel.fromJson(Map<String, dynamic> json, [String? id]) {
    return FacilityModel(
      id: id ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      capacity: int.tryParse(json['capacity']?.toString() ?? '25') ?? 25,
      currentOccupancy: int.tryParse(json['current_occupancy']?.toString() ?? json['currentOccupancy']?.toString() ?? '0') ?? 0,
      status: json['status']?.toString() ?? 'open',
      operatingHours: json['operating_hours']?.toString() ?? json['operatingHours']?.toString() ?? '8:00 AM - 11:00 PM',
      iconName: json['icon_name']?.toString() ?? json['iconName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'capacity': capacity,
      'current_occupancy': currentOccupancy,
      'status': status,
      'operating_hours': operatingHours,
      'icon_name': iconName,
    };
  }

  factory FacilityModel.fromEntity(FacilityEntity entity) {
    return FacilityModel(
      id: entity.id,
      name: entity.name,
      description: entity.description,
      capacity: entity.capacity,
      currentOccupancy: entity.currentOccupancy,
      status: entity.status,
      operatingHours: entity.operatingHours,
      iconName: entity.iconName,
    );
  }
}

class EquipmentModel extends EquipmentEntity {
  const EquipmentModel({
    required super.id,
    required super.facilityId,
    required super.facilityName,
    required super.name,
    required super.category,
    required super.serialNumber,
    super.status,
    required super.lastMaintained,
    required super.nextMaintenanceDate,
    super.notes,
  });

  factory EquipmentModel.fromJson(Map<String, dynamic> json, [String? id]) {
    return EquipmentModel(
      id: id ?? json['id']?.toString() ?? '',
      facilityId: json['facility_id']?.toString() ?? json['facilityId']?.toString() ?? '',
      facilityName: json['facility_name']?.toString() ?? json['facilityName']?.toString() ?? 'Main Gym Area',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Strength',
      serialNumber: json['serial_number']?.toString() ?? json['serialNumber']?.toString() ?? '',
      status: json['status']?.toString() ?? 'operational',
      lastMaintained: json['last_maintained'] != null
          ? DateTime.tryParse(json['last_maintained'].toString()) ?? DateTime.now().subtract(const Duration(days: 30))
          : DateTime.now().subtract(const Duration(days: 30)),
      nextMaintenanceDate: json['next_maintenance_date'] != null
          ? DateTime.tryParse(json['next_maintenance_date'].toString()) ?? DateTime.now().add(const Duration(days: 60))
          : DateTime.now().add(const Duration(days: 60)),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'facility_id': facilityId,
      'facility_name': facilityName,
      'name': name,
      'category': category,
      'serial_number': serialNumber,
      'status': status,
      'last_maintained': lastMaintained.toIso8601String(),
      'next_maintenance_date': nextMaintenanceDate.toIso8601String(),
      'notes': notes,
    };
  }

  factory EquipmentModel.fromEntity(EquipmentEntity entity) {
    return EquipmentModel(
      id: entity.id,
      facilityId: entity.facilityId,
      facilityName: entity.facilityName,
      name: entity.name,
      category: entity.category,
      serialNumber: entity.serialNumber,
      status: entity.status,
      lastMaintained: entity.lastMaintained,
      nextMaintenanceDate: entity.nextMaintenanceDate,
      notes: entity.notes,
    );
  }
}
