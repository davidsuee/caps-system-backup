import '../../domain/entities/workout_plan_entity.dart';

class ExerciseModel extends ExerciseEntity {
  const ExerciseModel({
    required super.name,
    required super.muscleGroup,
    required super.sets,
    required super.reps,
    required super.restSec,
    required super.equipment,
    super.instructions,
    super.isCompleted,
    super.dayTag,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      name: json['name'] ?? '',
      muscleGroup: json['muscle_group'] ?? json['muscleGroup'] ?? '',
      sets: json['sets']?.toString() ?? '3',
      reps: json['reps']?.toString() ?? '10',
      restSec: json['rest_sec'] is num ? (json['rest_sec'] as num).toInt() : 60,
      equipment: json['equipment'] ?? 'Gym Equipment',
      instructions: json['instructions'],
      isCompleted: json['isCompleted'] ?? false,
      dayTag: json['day_tag'] ?? json['dayTag'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'muscle_group': muscleGroup,
      'sets': sets,
      'reps': reps,
      'rest_sec': restSec,
      'equipment': equipment,
      'instructions': instructions,
      'isCompleted': isCompleted,
      'day_tag': dayTag,
    };
  }
}

class WorkoutPlanModel extends WorkoutPlanEntity {
  const WorkoutPlanModel({
    required super.id,
    required super.userId,
    required super.splitTitle,
    required super.confidenceScore,
    required super.source,
    required super.summary,
    required super.exercises,
    required super.generatedAt,
    super.isCoachApproved,
    super.coachNotes,
  });

  factory WorkoutPlanModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final rawList = ((json['routine'] ?? json['exercises']) as List?) ?? <dynamic>[];
    final List<ExerciseEntity> exercisesList = rawList
        .map<ExerciseEntity>((e) => ExerciseModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final planId = (id != null && id.isNotEmpty)
        ? id
        : (json['id'] != null && json['id'].toString().isNotEmpty)
            ? json['id'].toString()
            : 'workout_${DateTime.now().millisecondsSinceEpoch}';

    return WorkoutPlanModel(
      id: planId,
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      splitTitle: (json['recommended_split'] ?? json['splitTitle'] ?? 'Custom Plan').toString(),
      confidenceScore: ((json['confidence_score'] ?? json['confidenceScore']) as num?)?.toDouble() ?? 0.85,
      source: (json['source'] ?? 'ml_model_v1').toString(),
      summary: (json['summary'] ?? '').toString(),
      exercises: exercisesList,
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isCoachApproved: json['isCoachApproved'] == true,
      coachNotes: json['coachNotes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'splitTitle': splitTitle,
      'confidenceScore': confidenceScore,
      'source': source,
      'summary': summary,
      'exercises': exercises.map((e) => (e is ExerciseModel ? e : ExerciseModel(
        name: e.name,
        muscleGroup: e.muscleGroup,
        sets: e.sets,
        reps: e.reps,
        restSec: e.restSec,
        equipment: e.equipment,
        instructions: e.instructions,
        isCompleted: e.isCompleted,
        dayTag: e.dayTag,
      )).toJson()).toList(),
      'generatedAt': generatedAt.toIso8601String(),
      'isCoachApproved': isCoachApproved,
      'coachNotes': coachNotes,
    };
  }

  @override
  WorkoutPlanModel copyWith({
    String? id,
    String? userId,
    String? splitTitle,
    double? confidenceScore,
    String? source,
    String? summary,
    List<ExerciseEntity>? exercises,
    DateTime? generatedAt,
    bool? isCoachApproved,
    String? coachNotes,
  }) {
    return WorkoutPlanModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      splitTitle: splitTitle ?? this.splitTitle,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      source: source ?? this.source,
      summary: summary ?? this.summary,
      exercises: exercises ?? this.exercises,
      generatedAt: generatedAt ?? this.generatedAt,
      isCoachApproved: isCoachApproved ?? this.isCoachApproved,
      coachNotes: coachNotes ?? this.coachNotes,
    );
  }
}

