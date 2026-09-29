import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/progress_log_entity.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../data/repositories/progress_repository_impl.dart';
import '../../../domain/entities/user_entity.dart';
import '../../auth/providers/auth_provider.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return ProgressRepositoryImpl();
});

class ProgressState {
  final List<ProgressLogEntity> logs;
  final bool isLoading;
  final String? errorMessage;

  const ProgressState({
    this.logs = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ProgressState copyWith({
    List<ProgressLogEntity>? logs,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ProgressState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class ProgressNotifier extends Notifier<ProgressState> {
  late ProgressRepository _repo;

  @override
  ProgressState build() {
    _repo = ref.read(progressRepositoryProvider);
    ref.watch(authNotifierProvider.select((s) => s.user?.id));
    return const ProgressState();
  }

  void reset() {
    state = const ProgressState();
  }

  Future<void> loadLogs(String userId, {UserEntity? user}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      var list = List<ProgressLogEntity>.from(await _repo.getProgressLogs(userId, user?.email, user?.name));
      if (list.isEmpty && user != null && user.id == userId) {
        final baselineLog = ProgressLogEntity(
          id: const Uuid().v4(),
          userId: userId,
          date: user.createdAt,
          weightKg: user.weightKg,
          notes: 'Initial weigh-in',
        );
        await _repo.addProgressLog(baselineLog);
        list = [baselineLog];
      }
      list.sort((a, b) => a.date.compareTo(b.date));
      state = state.copyWith(logs: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addLog({
    required String userId,
    required double weightKg,
    double? bodyFat,
    String? notes,
    UserEntity? user,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // If user has no logs yet, make sure their baseline log from registration exists first
      if (state.logs.isEmpty && user != null && user.id == userId) {
        final baselineLog = ProgressLogEntity(
          id: const Uuid().v4(),
          userId: userId,
          date: user.createdAt,
          weightKg: user.weightKg,
          notes: 'Initial weigh-in',
        );
        await _repo.addProgressLog(baselineLog);
      }

      final log = ProgressLogEntity(
        id: const Uuid().v4(),
        userId: userId,
        date: DateTime.now(),
        weightKg: weightKg,
        bodyFatPercent: bodyFat,
        notes: notes,
      );
      await _repo.addProgressLog(log);
      final list = List<ProgressLogEntity>.from(await _repo.getProgressLogs(userId, user?.email, user?.name));
      list.sort((a, b) => a.date.compareTo(b.date));
      state = state.copyWith(logs: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final progressNotifierProvider = NotifierProvider<ProgressNotifier, ProgressState>(ProgressNotifier.new);
