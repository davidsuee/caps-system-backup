import '../entities/progress_log_entity.dart';

abstract class ProgressRepository {
  Future<List<ProgressLogEntity>> getProgressLogs(String userId, [String? userEmail, String? userName]);
  Future<void> addProgressLog(ProgressLogEntity log);
}
