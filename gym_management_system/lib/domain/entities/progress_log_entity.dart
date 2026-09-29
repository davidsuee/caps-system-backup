class ProgressLogEntity {
  final String id;
  final String userId;
  final DateTime date;
  final double weightKg;
  final double? bodyFatPercent;
  final String? notes;

  const ProgressLogEntity({
    required this.id,
    required this.userId,
    required this.date,
    required this.weightKg,
    this.bodyFatPercent,
    this.notes,
  });
}
