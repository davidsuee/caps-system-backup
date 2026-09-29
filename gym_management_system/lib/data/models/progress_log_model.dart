import '../../domain/entities/progress_log_entity.dart';

class ProgressLogModel extends ProgressLogEntity {
  const ProgressLogModel({
    required super.id,
    required super.userId,
    required super.date,
    required super.weightKg,
    super.bodyFatPercent,
    super.notes,
  });

  factory ProgressLogModel.fromJson(Map<String, dynamic> json, [String? id]) {
    final logId = (id != null && id.isNotEmpty)
        ? id
        : (json['id'] != null && json['id'].toString().isNotEmpty)
            ? json['id'].toString()
            : 'log_${DateTime.now().millisecondsSinceEpoch}';

    return ProgressLogModel(
      id: logId,
      userId: (json['userId'] ?? json['user_id'] ?? '').toString(),
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      weightKg: ((json['weight_kg'] ?? json['weight']) as num?)?.toDouble() ?? 70.0,
      bodyFatPercent: ((json['bodyFatPercent'] ?? json['body_fat']) as num?)?.toDouble(),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'date': date.toIso8601String(),
      'weight_kg': weightKg,
      'bodyFatPercent': bodyFatPercent,
      'notes': notes,
    };
  }
}
