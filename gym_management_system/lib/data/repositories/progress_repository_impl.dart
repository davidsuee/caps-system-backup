import '../../config/env.dart';
import '../../domain/entities/progress_log_entity.dart';
import '../../domain/repositories/progress_repository.dart';
import '../models/progress_log_model.dart';
import '../datasources/remote/firestore_service.dart';
import '../datasources/local/local_cache_service.dart';

class ProgressRepositoryImpl implements ProgressRepository {
  final FirestoreService _firestore;
  final LocalCacheService _localCache;

  ProgressRepositoryImpl({
    FirestoreService? firestore,
    LocalCacheService? localCache,
  })  : _firestore = firestore ?? FirestoreService(),
        _localCache = localCache ?? LocalCacheService();

  @override
  Future<List<ProgressLogEntity>> getProgressLogs(String userId, [String? userEmail, String? userName]) async {
    if (Env.useFirebase) {
      try {
        final list = await _firestore.getProgressLogs(userId, userEmail, userName);
        if (list.isNotEmpty) {
          _localCache.saveProgressLogs(list);
          return list;
        }
      } catch (_) {}
    }
    return _localCache.getProgressLogs(userId, userEmail, userName);
  }

  @override
  Future<void> addProgressLog(ProgressLogEntity log) async {
    final model = log is ProgressLogModel
        ? log
        : ProgressLogModel(
            id: log.id,
            userId: log.userId,
            date: log.date,
            weightKg: log.weightKg,
            bodyFatPercent: log.bodyFatPercent,
            notes: log.notes,
          );

    if (Env.useFirebase) {
      try {
        await _firestore.addProgressLog(model);
      } catch (_) {}
    }
    _localCache.addProgressLog(model);
  }
}
