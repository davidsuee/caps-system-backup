class ExerciseEntity {
  final String name;
  final String muscleGroup;
  final String sets;
  final String reps;
  final int restSec;
  final String equipment;
  final String? instructions;
  final bool isCompleted;
  final String dayTag;

  const ExerciseEntity({
    required this.name,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSec,
    required this.equipment,
    this.instructions,
    this.isCompleted = false,
    this.dayTag = '',
  });

  ExerciseEntity copyWith({
    String? name,
    String? muscleGroup,
    String? sets,
    String? reps,
    int? restSec,
    String? equipment,
    String? instructions,
    bool? isCompleted,
    String? dayTag,
  }) {
    return ExerciseEntity(
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      restSec: restSec ?? this.restSec,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      isCompleted: isCompleted ?? this.isCompleted,
      dayTag: dayTag ?? this.dayTag,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseEntity &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          dayTag == other.dayTag &&
          isCompleted == other.isCompleted;

  @override
  int get hashCode => Object.hash(name, dayTag, isCompleted);
}

class WorkoutPlanEntity {
  final String id;
  final String userId;
  final String splitTitle;
  final double confidenceScore;
  final String source; // "ml_model_v1" or "heuristic_fallback"
  final String summary;
  final List<ExerciseEntity> exercises;
  final DateTime generatedAt;

  final bool isCoachApproved;
  final String? coachNotes;

  const WorkoutPlanEntity({
    required this.id,
    required this.userId,
    required this.splitTitle,
    required this.confidenceScore,
    required this.source,
    required this.summary,
    required this.exercises,
    required this.generatedAt,
    this.isCoachApproved = false,
    this.coachNotes,
  });

  WorkoutPlanEntity copyWith({
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
    return WorkoutPlanEntity(
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
