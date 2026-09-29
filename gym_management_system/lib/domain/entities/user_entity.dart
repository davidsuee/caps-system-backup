enum UserRole {
  member,
  coach,
  admin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'coach':
      case 'trainer':
        return UserRole.coach;
      case 'admin':
      case 'staff':
        return UserRole.admin;
      default:
        return UserRole.member;
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.coach:
        return 'Coach';
      case UserRole.admin:
        return 'Admin / Staff';
      case UserRole.member:
        return 'Member';
    }
  }
}

class UserEntity {
  final String id;
  final String name;
  final String email;
  final UserRole role;
  final int age;
  final double heightCm;
  final double weightKg;
  final String gender;
  final String fitnessGoal;
  final String activityLevel;
  final String experienceLevel;
  final List<String> dietaryRestrictions;
  final List<String> availableEquipment;
  final List<String> injuryFlags;
  final String? profilePhotoUrl;
  final DateTime createdAt;
  final String? assignedCoachId;
  final String? specialization;
  final int maxClients;

  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.age = 25,
    this.heightCm = 170.0,
    this.weightKg = 70.0,
    this.gender = 'Male',
    this.fitnessGoal = 'Muscle Gain',
    this.activityLevel = 'Moderately Active',
    this.experienceLevel = 'Intermediate',
    this.dietaryRestrictions = const [],
    this.availableEquipment = const ['Full Gym'],
    this.injuryFlags = const [],
    this.profilePhotoUrl,
    required this.createdAt,
    this.assignedCoachId,
    this.specialization,
    this.maxClients = 8,
  });

  double get bmi {
    if (heightCm <= 0) return 0.0;
    final h = heightCm / 100.0;
    return double.parse((weightKg / (h * h)).toStringAsFixed(1));
  }

  UserEntity copyWith({
    String? id,
    String? name,
    String? email,
    UserRole? role,
    int? age,
    double? heightCm,
    double? weightKg,
    String? gender,
    String? fitnessGoal,
    String? activityLevel,
    String? experienceLevel,
    List<String>? dietaryRestrictions,
    List<String>? availableEquipment,
    List<String>? injuryFlags,
    String? profilePhotoUrl,
    DateTime? createdAt,
    String? assignedCoachId,
    String? specialization,
    int? maxClients,
  }) {
    return UserEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      age: age ?? this.age,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      gender: gender ?? this.gender,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      activityLevel: activityLevel ?? this.activityLevel,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
      availableEquipment: availableEquipment ?? this.availableEquipment,
      injuryFlags: injuryFlags ?? this.injuryFlags,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      createdAt: createdAt ?? this.createdAt,
      assignedCoachId: assignedCoachId ?? this.assignedCoachId,
      specialization: specialization ?? this.specialization,
      maxClients: maxClients ?? this.maxClients,
    );
  }
}
