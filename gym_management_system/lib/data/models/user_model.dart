import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.age,
    super.heightCm,
    super.weightKg,
    super.gender,
    super.fitnessGoal,
    super.activityLevel,
    super.experienceLevel,
    super.dietaryRestrictions,
    super.availableEquipment,
    super.injuryFlags,
    super.profilePhotoUrl,
    required super.createdAt,
    super.assignedCoachId,
    super.specialization,
    super.maxClients = 20,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final rawDiet = json['dietary_restrictions'] ?? json['dietaryRestrictions'];
    final rawEquip = json['available_equipment'] ?? json['availableEquipment'];
    final rawInjuries = json['injury_flags'] ?? json['injuryFlags'];

    return UserModel(
      id: id ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: UserRole.fromString(json['role']?.toString() ?? 'member'),
      age: int.tryParse(json['age']?.toString() ?? '') ?? 25,
      heightCm: double.tryParse((json['height_cm'] ?? json['height'] ?? 170.0).toString()) ?? 170.0,
      weightKg: double.tryParse((json['weight_kg'] ?? json['weight'] ?? 70.0).toString()) ?? 70.0,
      gender: json['gender']?.toString() ?? 'Male',
      fitnessGoal: json['fitness_goal']?.toString() ?? json['fitnessGoal']?.toString() ?? 'Muscle Gain',
      activityLevel: json['activity_level']?.toString() ?? json['activityLevel']?.toString() ?? 'Moderately Active',
      experienceLevel: json['experience_level']?.toString() ?? json['fitnessLevel']?.toString() ?? 'Intermediate',
      dietaryRestrictions: rawDiet is Iterable
          ? rawDiet.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
          : (json['dietaryPreference'] != null ? [json['dietaryPreference'].toString()] : const []),
      availableEquipment: rawEquip is Iterable
          ? rawEquip.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
          : const ['Full Gym'],
      injuryFlags: rawInjuries is Iterable
          ? rawInjuries.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList()
          : const [],
      profilePhotoUrl: json['profile_photo_url']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      assignedCoachId: json['assigned_coach_id']?.toString() ?? json['assignedCoachId']?.toString(),
      specialization: json['specialization']?.toString(),
      maxClients: int.tryParse((json['max_clients'] ?? json['maxClients'] ?? 20).toString()) ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'age': age,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'gender': gender,
      'fitness_goal': fitnessGoal,
      'activity_level': activityLevel,
      'experience_level': experienceLevel,
      'dietary_restrictions': dietaryRestrictions,
      'available_equipment': availableEquipment,
      'injury_flags': injuryFlags,
      'profile_photo_url': profilePhotoUrl,
      'createdAt': createdAt.toIso8601String(),
      'assigned_coach_id': assignedCoachId,
      'specialization': specialization,
      'max_clients': maxClients,
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      name: entity.name,
      email: entity.email,
      role: entity.role,
      age: entity.age,
      heightCm: entity.heightCm,
      weightKg: entity.weightKg,
      gender: entity.gender,
      fitnessGoal: entity.fitnessGoal,
      activityLevel: entity.activityLevel,
      experienceLevel: entity.experienceLevel,
      dietaryRestrictions: entity.dietaryRestrictions,
      availableEquipment: entity.availableEquipment,
      injuryFlags: entity.injuryFlags,
      profilePhotoUrl: entity.profilePhotoUrl,
      createdAt: entity.createdAt,
      assignedCoachId: entity.assignedCoachId,
      specialization: entity.specialization,
      maxClients: entity.maxClients,
    );
  }
}

