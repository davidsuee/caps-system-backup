import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/theme_toggle_button.dart';
import '../../../domain/entities/user_entity.dart';
import '../../../domain/entities/progress_log_entity.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/progress_log_model.dart';
import '../../../data/models/workout_plan_model.dart';
import '../../../data/models/meal_plan_model.dart';
import '../../../data/datasources/local/local_cache_service.dart';
import '../../../data/datasources/remote/firestore_service.dart';
import '../../../data/repositories/progress_repository_impl.dart';
import '../../../data/repositories/workout_repository_impl.dart';
import '../../../domain/entities/workout_plan_entity.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../config/env.dart';
import '../../admin/providers/admin_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/coach_provider.dart';

class CoachDashboardScreen extends ConsumerStatefulWidget {
  const CoachDashboardScreen({super.key});

  @override
  ConsumerState<CoachDashboardScreen> createState() => _CoachDashboardScreenState();
}

class _CoachDashboardScreenState extends ConsumerState<CoachDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, List<ProgressLogEntity>> _clientProgressLogs = {};
  final Map<String, WorkoutPlanModel> _clientWorkoutPlans = {};
  String? _selectedWorkoutDayTag;
  late final ProgressRepository _progressRepo;
  bool _isLoadingProgress = false;
  String _searchQuery = '';
  bool _showAllMembers = false;
  String? _selectedProgressClientId;
  bool _isProgressExpanded = false;

  @override
  void initState() {
    super.initState();
    _progressRepo = ProgressRepositoryImpl();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final coachState = ref.read(coachNotifierProvider);
      if (coachState.clients.isNotEmpty) {
        final firstClient = coachState.clients.first;
        _fetchClientProgress(firstClient);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchClientProgress(UserModel client) async {
    setState(() => _isLoadingProgress = true);
    try {
      final logs = await _progressRepo.getProgressLogs(client.id, client.email, client.name);
      if (mounted && logs.isNotEmpty) {
        setState(() {
          _clientProgressLogs[client.id] = logs;
        });
      }
    } catch (e) {
      debugPrint('[CoachDashboard] Error fetching progress for ${client.name}: $e');
    }

    try {
      final w = await WorkoutRepositoryImpl().getActiveWorkoutPlan(client.id);
      if (w != null && mounted) {
        setState(() {
          _clientWorkoutPlans[client.id] = w is WorkoutPlanModel
              ? w
              : WorkoutPlanModel(
                  id: w.id,
                  userId: w.userId,
                  splitTitle: w.splitTitle,
                  confidenceScore: w.confidenceScore,
                  source: w.source,
                  summary: w.summary,
                  exercises: w.exercises,
                  generatedAt: w.generatedAt,
                  isCoachApproved: w.isCoachApproved,
                  coachNotes: w.coachNotes,
                );
        });
      }
    } catch (e) {
      debugPrint('[CoachDashboard] Error fetching workout for ${client.name}: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingProgress = false);
      }
    }
  }

  void _scrollToProgress() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        380.0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _selectAndTrackClient(UserModel c) {
    setState(() {
      _selectedProgressClientId = c.id;
      _isProgressExpanded = true;
    });
    _fetchClientProgress(c);
    _scrollToProgress();
  }

  Future<void> _assignClientToMe(UserModel client, UserEntity? user) async {
    if (user == null) return;

    final coachState = ref.read(coachNotifierProvider);
    final maxCap = (user.maxClients > 0) ? user.maxClients : 20;
    final currentCount = coachState.clients.where((c) => c.assignedCoachId == user.id).length;
    if (currentCount >= maxCap) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capacity reached: You have reached the maximum limit of $maxCap assigned clients.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final mem = LocalCacheService().getMembership(client.id);
    final isDayPass = mem != null && (mem.planName.toLowerCase().contains('day') || mem.planName.toLowerCase().contains('walk'));
    if (isDayPass) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${client.name} has a 1-Day Pass (Self-Directed). Day pass walk-ins do not require coach assignment!'),
            backgroundColor: AppColors.accent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    final updated = client.copyWith(assignedCoachId: user.id);
    LocalCacheService().saveUser(UserModel.fromEntity(updated));
    if (Env.useFirebase) {
      try {
        await FirestoreService().saveUser(UserModel.fromEntity(updated));
      } catch (_) {}
    }
    await ref.read(coachNotifierProvider.notifier).loadDashboard(user.id);
    try {
      ref.read(adminNotifierProvider.notifier).loadDashboard();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${client.name} is now assigned to your roster!'),
          backgroundColor: AppColors.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  List<ProgressLogEntity> _getClientLogs(UserModel client) {
    if (_clientProgressLogs.containsKey(client.id) && _clientProgressLogs[client.id]!.isNotEmpty) {
      final list = List<ProgressLogEntity>.from(_clientProgressLogs[client.id]!);
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    }

    final cached = LocalCacheService().getProgressLogs(client.id, client.email, client.name);
    if (cached.isNotEmpty) {
      final list = List<ProgressLogEntity>.from(cached);
      list.sort((a, b) => a.date.compareTo(b.date));
      return list;
    }

    return [
      ProgressLogModel(
        id: 'baseline_${client.id}',
        userId: client.id,
        date: client.createdAt,
        weightKg: client.weightKg > 0 ? client.weightKg : 70.0,
        notes: 'Initial registration weigh-in',
      ),
    ];
  }

  // Progress weigh-ins are read-only for coaches. Only members can log their biometrics.

  void _showClientDetails(
    BuildContext context,
    WidgetRef ref,
    UserModel client,
    WorkoutPlanModel? workout,
    MealPlanModel? meal,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.name,
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${client.email} • ${client.gender}',
                                style: TextStyle(color: context.subtitleColor, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: context.mutedColor),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: context.borderLine),
                    const SizedBox(height: 14),

                    // Client Biometrics
                    Text(
                      'Client Biometrics & Goal',
                      style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _InfoBadge(label: 'Height', value: '${client.heightCm.toInt()} cm'),
                        _InfoBadge(label: 'Weight', value: '${client.weightKg.toStringAsFixed(1)} kg'),
                        _InfoBadge(label: 'BMI', value: client.bmi.toString()),
                        _InfoBadge(label: 'Age', value: '${client.age} yrs'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, color: AppColors.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Primary Goal: ${client.fitnessGoal} (${client.experienceLevel})',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Workout Routine Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Workout Routine',
                          style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (workout != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (workout.isCoachApproved ? AppColors.primary : AppColors.accent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              workout.isCoachApproved ? '✓ COACH APPROVED' : 'PENDING REVIEW',
                              style: TextStyle(
                                color: workout.isCoachApproved ? AppColors.primary : AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (workout != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              workout.splitTitle,
                              style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              workout.summary,
                              style: TextStyle(color: context.subtitleColor, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Prescribed Exercise Schedule (${workout.exercises.length} total):',
                              style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            ...List.generate(
                              workout.exercises.length,
                              (idx) {
                                final ex = workout.exercises[idx];
                                final isAccomplished = ex.isCompleted;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        isAccomplished ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
                                        size: 15,
                                        color: isAccomplished ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (ex.dayTag.isNotEmpty) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accent.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      ex.dayTag,
                                                      style: const TextStyle(color: AppColors.accent, fontSize: 10, fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    ex.name,
                                                    style: TextStyle(
                                                      color: isAccomplished ? AppColors.primary : context.titleColor,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (isAccomplished) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                                                    ),
                                                    child: const Text(
                                                      '✓ ACCOMPLISHED',
                                                      style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${ex.muscleGroup} • ${ex.sets} sets × ${ex.reps} • ${ex.restSec}s rest',
                                              style: TextStyle(color: context.subtitleColor, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final newPlan = await ref.read(coachNotifierProvider.notifier).generateWorkoutForClient(client);
                                      setModalState(() {});
                                      if (context.mounted && newPlan != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Routine refreshed and re-optimized for ${client.name}!'),
                                            backgroundColor: AppColors.primary,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                                    label: const Text('Re-generate AI Routine', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: context.cardColor,
                                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (!workout.isCoachApproved)
                              CustomButton(
                                text: 'Approve Workout Routine',
                                icon: Icons.check_circle_outline,
                                onPressed: () async {
                                  await ref.read(coachNotifierProvider.notifier).approveWorkout(client.id);
                                  setModalState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Workout routine approved for ${client.name}!'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                },
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 16, color: AppColors.primary),
                                      SizedBox(width: 6),
                                      Text(
                                        'Verified & Approved by Coach',
                                        style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No workout routine generated yet for this member.',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            CustomButton(
                              text: '✨ Generate AI Routine for ${client.name}',
                              icon: Icons.auto_awesome_rounded,
                              onPressed: () async {
                                final newPlan = await ref.read(coachNotifierProvider.notifier).generateWorkoutForClient(client);
                                setModalState(() {});
                                if (context.mounted && newPlan != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Personalized routine generated and approved for ${client.name}!'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Meal Plan Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assigned Nutrition & Meal Plan',
                          style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        if (meal != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (meal.isCoachApproved ? AppColors.accentCyan : AppColors.accent)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meal.isCoachApproved ? '✓ COACH APPROVED' : 'PENDING REVIEW',
                              style: TextStyle(
                                color: meal.isCoachApproved ? AppColors.accentCyan : AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (meal != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Target: ${meal.totalCalories.toInt()} kcal / day',
                              style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Protein: ${meal.totalProtein.toInt()}g • Carbs: ${meal.totalCarbs.toInt()}g • Fat: ${meal.totalFat.toInt()}g',
                              style: TextStyle(color: context.subtitleColor, fontSize: 13),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Meal Breakdown (${meal.meals.length} meals):',
                              style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            ...meal.meals.map((m) {
                              final foodNames = m.items.map((i) => i.name).join(', ');
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.restaurant_menu_rounded, size: 14, color: AppColors.accent),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${m.mealName}: $foodNames (${m.slotCalories.toInt()} kcal)',
                                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      final newPlan = await ref.read(coachNotifierProvider.notifier).generateMealForClient(client);
                                      setModalState(() {});
                                      if (context.mounted && newPlan != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Meal plan re-optimized and approved for ${client.name}!'),
                                            backgroundColor: AppColors.primary,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.accentCyan),
                                    label: const Text('Re-optimize Meal Plan', style: TextStyle(color: AppColors.accentCyan, fontSize: 12)),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: context.cardColor,
                                      side: BorderSide(color: AppColors.accentCyan.withValues(alpha: 0.5)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            if (!meal.isCoachApproved)
                              CustomButton(
                                text: 'Approve Meal Plan',
                                icon: Icons.check_circle_outline,
                                onPressed: () async {
                                  await ref.read(coachNotifierProvider.notifier).approveMeal(client.id);
                                  setModalState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Meal plan approved for ${client.name}!'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                },
                              )
                            else
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                                ),
                                child: const Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 16, color: AppColors.accentCyan),
                                      SizedBox(width: 6),
                                      Text(
                                        'Verified & Approved by Coach',
                                        style: TextStyle(color: AppColors.accentCyan, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.elevatedSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.accentCyan, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No meal plan generated yet for this member.',
                                    style: TextStyle(color: context.subtitleColor, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            CustomButton(
                              text: '✨ Generate Optimal Meal Plan for ${client.name}',
                              icon: Icons.restaurant_menu_rounded,
                              onPressed: () async {
                                final newPlan = await ref.read(coachNotifierProvider.notifier).generateMealForClient(client);
                                setModalState(() {});
                                if (context.mounted && newPlan != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Optimal meal plan generated and approved for ${client.name}!'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showScheduleSessionDialog(
    BuildContext context,
    WidgetRef ref,
    dynamic coach,
    List<UserModel> clients,
  ) {
    // STRICT ASSIGNMENT RESTRICTION:
    // A coach can ONLY schedule 1-on-1 training sessions with clients currently assigned to them!
    final assignedClients = clients.where((c) => c.assignedCoachId == coach.id).toList();

    if (assignedClients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No assigned clients available. You can only schedule 1-on-1 training sessions with clients assigned to your roster.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    String selectedMemberId = assignedClients.first.id;
    String selectedFocus = 'Strength & Technique Coaching';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    String? validationError;

    final focusOptions = [
      'Strength & Technique Coaching',
      'Hypertrophy & Form Check',
      'Biometric Weigh-in & Consultation',
      'Cardio & Conditioning Session',
      'Nutrition & Macro Planning',
    ];

    bool isOutsideOperatingHours(TimeOfDay t) {
      return t.hour < 8 || t.hour > 23 || (t.hour == 23 && t.minute > 0);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surfaceBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Schedule Training Session',
                        style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: context.mutedColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Operating Hours Info Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gym Operating Hours: 8:00 AM – 11:00 PM Daily',
                            style: TextStyle(color: context.titleColor, fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Select Assigned Client (${assignedClients.length} available)',
                    style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedMemberId,
                        isExpanded: true,
                        dropdownColor: context.cardColor,
                        items: assignedClients.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.name} (${c.fitnessGoal})', style: TextStyle(color: context.titleColor)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedMemberId = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Session Focus / Program',
                    style: TextStyle(color: context.subtitleColor, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedFocus,
                        isExpanded: true,
                        dropdownColor: context.cardColor,
                        items: focusOptions.map((f) {
                          return DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: context.titleColor)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => selectedFocus = val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) {
                              setModalState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.accent),
                          label: Text(
                            DateFormat('MMM dd, yyyy').format(selectedDate),
                            style: TextStyle(color: context.titleColor, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: context.cardColor,
                            side: BorderSide(color: context.borderLine),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (picked != null) {
                              if (isOutsideOperatingHours(picked)) {
                                setModalState(() {
                                  validationError = 'Gym closed: Sessions must be scheduled between 8:00 AM and 11:00 PM.';
                                });
                              } else {
                                setModalState(() {
                                  selectedTime = picked;
                                  validationError = null;
                                });
                              }
                            }
                          },
                          icon: const Icon(Icons.access_time, size: 16, color: AppColors.accent),
                          label: Text(
                            selectedTime.format(context),
                            style: TextStyle(color: context.titleColor, fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: context.cardColor,
                            side: BorderSide(
                              color: validationError != null ? AppColors.error : context.borderLine,
                            ),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (validationError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              validationError!,
                              style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  CustomButton(
                    text: 'Confirm & Schedule Session',
                    icon: Icons.check,
                    onPressed: () async {
                      if (isOutsideOperatingHours(selectedTime)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot schedule session: Operating hours are 8:00 AM to 11:00 PM Daily.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      if (!assignedClients.any((c) => c.id == selectedMemberId)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('You can only schedule training sessions with your assigned clients.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      final client = assignedClients.firstWhere((c) => c.id == selectedMemberId);
                      final fullDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      final session = TrainingSessionModel(
                        id: const Uuid().v4(),
                        coachId: coach.id as String,
                        coachName: coach.name as String,
                        memberId: client.id,
                        memberName: client.name,
                        dateTime: fullDateTime,
                        focus: selectedFocus,
                        status: 'Confirmed',
                      );

                      final success = await ref.read(coachNotifierProvider.notifier).scheduleSession(session);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success
                                ? 'Training session booked with ${client.name}!'
                                : ref.read(coachNotifierProvider).errorMessage ?? 'Failed to schedule session.'),
                            backgroundColor: success ? AppColors.primary : AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      height: 42,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: TextStyle(color: context.titleColor, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search client by name, goal, email...',
          hintStyle: TextStyle(color: context.mutedColor, fontSize: 12),
          prefixIcon: Icon(Icons.search_rounded, color: context.mutedColor, size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 16, color: context.mutedColor),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: context.elevatedSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.borderLine),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final coachState = ref.watch(coachNotifierProvider);
    final reviewedRoutinesCount = coachState.clientWorkouts.values.where((w) => w != null).length;
    final approvedRoutinesCount = coachState.clientWorkouts.values.where((w) => w?.isCoachApproved == true).length;

    final allGymMembers = LocalCacheService().getUsersByRole(UserRole.member);
    final Map<String, UserModel> memberMap = {};
    for (final m in allGymMembers) {
      memberMap[m.id] = m;
    }
    for (final m in coachState.clients) {
      memberMap[m.id] = m;
    }
    final allUniqueMembers = memberMap.values.toList();

    final q = _searchQuery.trim().toLowerCase();

    final matchingAll = q.isEmpty
        ? (_showAllMembers ? allUniqueMembers : coachState.clients)
        : allUniqueMembers.where((c) {
            final nameMatches = c.name.toLowerCase().contains(q);
            final emailMatches = c.email.toLowerCase().contains(q);
            final goalMatches = c.fitnessGoal.toLowerCase().contains(q);
            final expMatches = c.experienceLevel.toLowerCase().contains(q);
            return nameMatches || emailMatches || goalMatches || expMatches;
          }).toList();

    final matchingAssigned = q.isEmpty
        ? coachState.clients
        : matchingAll.where((c) =>
            coachState.clients.any((client) => client.id == c.id) ||
            (user != null && c.assignedCoachId == user.id)
          ).toList();

    final matchingOther = q.isEmpty
        ? const <UserModel>[]
        : matchingAll.where((c) =>
            !matchingAssigned.any((client) => client.id == c.id)
          ).toList();

    final displayedClients = q.isEmpty
        ? (_showAllMembers ? allUniqueMembers : coachState.clients)
        : matchingAssigned;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach & Trainer Portal'),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Roster',
            onPressed: () => ref.read(coachNotifierProvider.notifier).loadDashboard(user?.id),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error),
            tooltip: 'Sign Out',
            onPressed: () async {
              context.go(AppRoutes.welcome);
              await ref.read(authNotifierProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(coachNotifierProvider.notifier).loadDashboard(user?.id);
            final coachState = ref.read(coachNotifierProvider);
            if (coachState.clients.isNotEmpty) {
              final active = coachState.clients.firstWhere(
                (c) => c.id == _selectedProgressClientId,
                orElse: () => coachState.clients.first,
              );
              await _fetchClientProgress(active);
            }
          },
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Welcome Trainer Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.2),
                      context.cardColor,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: context.isDark ? AppColors.accent.withValues(alpha: 0.4) : context.borderLine),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sports_gymnastics_rounded, color: AppColors.accent, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'Coach Portal',
                                style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Fitness Coach • Workout & Nutrition Supervisor',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CoachStat('${coachState.clients.length}', 'Active Clients'),
                        _CoachStat('$reviewedRoutinesCount', 'Routines Active'),
                        _CoachStat('$approvedRoutinesCount', 'Approved Plans'),
                        _CoachStat('${coachState.sessions.length}', 'Sessions Booked'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Quick Action
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderLine),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (user != null) {
                        _showScheduleSessionDialog(context, ref, user, coachState.clients);
                      }
                    },
                    icon: const Icon(Icons.calendar_month, size: 18, color: Colors.black),
                    label: const Text('+ Schedule Training Session', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Scheduled Training Sessions Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Training Sessions (${coachState.sessions.length})',
                    style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  InkWell(
                    onTap: () {
                      if (user != null) {
                        _showScheduleSessionDialog(context, ref, user, coachState.clients);
                      }
                    },
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 16, color: AppColors.accent),
                        SizedBox(width: 4),
                        Text('Book Session', style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (coachState.sessions.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Center(
                    child: Text(
                      'No upcoming sessions scheduled yet. Tap "Book Session" to schedule.',
                      style: TextStyle(color: context.mutedColor, fontSize: 12),
                    ),
                  ),
                ),
              ] else ...[
                ...coachState.sessions.map((s) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.event_available_rounded, color: AppColors.accent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.memberName,
                                style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${s.focus} • ${DateFormat('MMM dd, hh:mm a').format(s.dateTime)}',
                                style: TextStyle(color: context.subtitleColor, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.status.toUpperCase(),
                            style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                          tooltip: 'Cancel Session',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: context.cardColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: Text('Cancel Session', style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w800)),
                                content: Text(
                                  'Are you sure you want to cancel the scheduled training session with ${s.memberName} on ${DateFormat('MMM dd, hh:mm a').format(s.dateTime)}?',
                                  style: TextStyle(color: context.subtitleColor),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Keep', style: TextStyle(color: context.mutedColor)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Cancel Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await ref.read(coachNotifierProvider.notifier).cancelSession(s.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Session with ${s.memberName} has been cancelled.'),
                                    backgroundColor: AppColors.accent,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 24),

              // Assigned Client Roster with Search Bar
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 650;
                  final titleWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _showAllMembers
                            ? 'All Registered Members (${allUniqueMembers.length})'
                            : 'Assigned Client Roster (${matchingAssigned.length}${matchingAssigned.length != coachState.clients.length ? ' of ${coachState.clients.length}' : ''})',
                        style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      if (coachState.isLoading) ...[
                        const SizedBox(width: 10),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                      ],
                    ],
                  );

                  if (isWide) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(child: titleWidget),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 320,
                          child: _buildSearchBar(),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        titleWidget,
                        const SizedBox(height: 12),
                        _buildSearchBar(),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 12),

              // Roster Scope Tabs (Assigned to Me vs All Gym Members)
              Row(
                children: [
                  ChoiceChip(
                    label: Text('My Clients (${coachState.clients.length})'),
                    selected: !_showAllMembers && q.isEmpty,
                    selectedColor: AppColors.accent,
                    backgroundColor: context.cardColor,
                    labelStyle: TextStyle(
                      color: (!_showAllMembers && q.isEmpty) ? Colors.black : context.subtitleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _showAllMembers = false;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text('All Gym Members (${allUniqueMembers.length})'),
                    selected: _showAllMembers && q.isEmpty,
                    selectedColor: AppColors.accent,
                    backgroundColor: context.cardColor,
                    labelStyle: TextStyle(
                      color: (_showAllMembers && q.isEmpty) ? Colors.black : context.subtitleColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _showAllMembers = true;
                        _searchController.clear();
                        _searchQuery = '';
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Client Progress Tracking (Directly underneath search bar & roster scope chips)
              if (displayedClients.isNotEmpty || allUniqueMembers.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final clientPool = displayedClients.isNotEmpty ? displayedClients : allUniqueMembers;
                    final activeClient = clientPool.firstWhere(
                      (cl) => cl.id == _selectedProgressClientId,
                      orElse: () => clientPool.first,
                    );
                    return _buildClientProgressSection(
                      activeClient: activeClient,
                      availableClients: allUniqueMembers,
                      coachUser: user,
                    );
                  },
                ),
                const SizedBox(height: 14),
              ],

              if (coachState.isLoading && displayedClients.isEmpty && allUniqueMembers.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                ),
              ] else if (displayedClients.isEmpty && q.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.person_outline, color: context.mutedColor, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'No clients registered yet',
                          style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'New registered members will appear here automatically',
                          style: TextStyle(color: context.subtitleColor, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (q.isNotEmpty && matchingAll.isEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.person_search_rounded, color: context.mutedColor, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'No clients match "$_searchQuery"',
                          style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try searching with a different name, fitness goal, or email',
                          style: TextStyle(color: context.subtitleColor, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.primary),
                          label: const Text('Clear search filter', style: TextStyle(color: AppColors.primary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (q.isNotEmpty) ...[
                // Search Results: Assigned Clients matching query
                if (matchingAssigned.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Your Assigned Clients (${matchingAssigned.length})',
                      style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  ...matchingAssigned.map((c) => _buildClientCard(c, coachState, user)),
                ],

                // Search Results: Other Gym Members matching query
                if (matchingOther.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people_outline_rounded, color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Other Registered Members (${matchingOther.length})',
                          style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  ...matchingOther.map((c) => _buildOtherMemberCard(c, coachState, user)),
                ],
              ] else ...[
                ...displayedClients.map((c) {
                  final isMyClient = coachState.clients.any((cl) => cl.id == c.id) ||
                      (user != null && c.assignedCoachId == user.id);
                  if (isMyClient) {
                    return _buildClientCard(c, coachState, user);
                  } else {
                    return _buildOtherMemberCard(c, coachState, user);
                  }
                }),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClientProgressSection({
    required UserModel activeClient,
    required List<UserModel> availableClients,
    required UserEntity? coachUser,
  }) {
    final logs = _getClientLogs(activeClient);
    final currentWeight = logs.isNotEmpty ? logs.last.weightKg : activeClient.weightKg;
    final initialWeight = logs.isNotEmpty ? logs.first.weightKg : activeClient.weightKg;
    final delta = currentWeight - initialWeight;

    final coachState = ref.watch(coachNotifierProvider);
    final workout = _clientWorkoutPlans[activeClient.id] ??
        coachState.clientWorkouts[activeClient.id] ??
        LocalCacheService().getWorkoutPlan(activeClient.id);
    final mem = LocalCacheService().getMembership(activeClient.id);
    final isDayPass = mem != null && (mem.planName.toLowerCase().contains('day') || mem.planName.toLowerCase().contains('walk'));
    final hasCoachPlan = !isDayPass;

    final allDayTags = <String>[];
    if (workout != null) {
      for (final ex in workout.exercises) {
        if (ex.dayTag.isNotEmpty && !allDayTags.contains(ex.dayTag)) {
          allDayTags.add(ex.dayTag);
        }
      }
    }

    final activeDay = (_selectedWorkoutDayTag != null && allDayTags.contains(_selectedWorkoutDayTag))
        ? _selectedWorkoutDayTag!
        : (allDayTags.isNotEmpty
            ? (allDayTags.firstWhere(
                (tag) => workout!.exercises.any((e) => e.dayTag == tag && e.isCompleted),
                orElse: () => allDayTags.first,
              ))
            : null);

    final displayedExercises = (workout != null && activeDay != null && allDayTags.length > 1)
        ? workout.exercises.where((e) => e.dayTag == activeDay).toList()
        : (workout?.exercises ?? []);

    final completedCount = displayedExercises.where((e) => e.isCompleted).length;
    final totalCount = displayedExercises.length;
    final progressRatio = totalCount > 0 ? completedCount / totalCount : 0.0;

    // Ensure active client exists in dropdown list
    final dropdownClients = availableClients.any((c) => c.id == activeClient.id)
        ? availableClients
        : [activeClient, ...availableClients];

    if (!_isProgressExpanded) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  'Progress Tracking',
                  style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: activeClient.id,
                        isDense: true,
                        isExpanded: true,
                        dropdownColor: context.cardColor,
                        items: dropdownClients.map((cl) {
                          return DropdownMenuItem(
                            value: cl.id,
                            child: Text(
                              '${cl.name} • ${cl.fitnessGoal}',
                              style: TextStyle(color: context.titleColor, fontSize: 11, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedProgressClientId = val);
                            final target = dropdownClients.firstWhere((cl) => cl.id == val, orElse: () => activeClient);
                            _fetchClientProgress(target);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () {
                    setState(() => _isProgressExpanded = true);
                    _fetchClientProgress(activeClient);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.show_chart_rounded, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text('Trend', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                        Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Current: ${currentWeight.toStringAsFixed(1)} kg',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  'Change: ${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                  style: TextStyle(
                    color: delta <= 0 ? AppColors.primary : AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
                if (hasCoachPlan && workout != null && totalCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: (completedCount > 0 ? AppColors.primary : context.elevatedSurface).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: completedCount > 0 ? AppColors.primary.withValues(alpha: 0.5) : context.borderLine,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          completedCount > 0 ? Icons.check_circle_rounded : Icons.fitness_center_rounded,
                          size: 11,
                          color: completedCount > 0 ? AppColors.primary : context.subtitleColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Today: $completedCount/$totalCount done',
                          style: TextStyle(
                            color: completedCount > 0 ? AppColors.primary : context.subtitleColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 10, color: context.mutedColor),
                      const SizedBox(width: 4),
                      Text(
                        'Member-Logged',
                        style: TextStyle(color: context.mutedColor, fontSize: 10, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.insights_rounded, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Client Progress Tracking',
                                style: TextStyle(
                                  color: context.titleColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (_isLoadingProgress) ...[
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'Live biometric weigh-ins & body progression',
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.elevatedSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.borderLine),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.visibility_outlined, size: 13, color: context.subtitleColor),
                          const SizedBox(width: 5),
                          Text(
                            'View Only',
                            style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: context.mutedColor,
                      ),
                      tooltip: 'Collapse',
                      onPressed: () => setState(() => _isProgressExpanded = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                        child: Text(
                          activeClient.name.isNotEmpty ? activeClient.name[0].toUpperCase() : 'C',
                          style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Tracking:',
                        style: TextStyle(color: context.mutedColor, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: activeClient.id,
                            isDense: true,
                            isExpanded: true,
                            dropdownColor: context.cardColor,
                            items: dropdownClients.map((cl) {
                              return DropdownMenuItem(
                                value: cl.id,
                                child: Text(
                                  '${cl.name} • ${cl.fitnessGoal}',
                                  style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedProgressClientId = val);
                                final target = dropdownClients.firstWhere((cl) => cl.id == val, orElse: () => activeClient);
                                _fetchClientProgress(target);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.borderLine),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Today's Accomplished Workout Section
                  _buildTodayWorkoutAccomplishmentCard(
                    activeClient: activeClient,
                    workout: workout,
                    hasCoachPlan: hasCoachPlan,
                    planName: mem?.planName,
                    isDayPass: isDayPass,
                    allDayTags: allDayTags,
                    activeDay: activeDay,
                    displayedExercises: displayedExercises,
                    completedCount: completedCount,
                    totalCount: totalCount,
                    progressRatio: progressRatio,
                  ),

                  // 3 KPI Tiles: Current Weight, Total Change, Goal & BMI
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.elevatedSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Current Weight', style: TextStyle(color: context.subtitleColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                '${currentWeight.toStringAsFixed(1)} kg',
                                style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                logs.isNotEmpty ? DateFormat('MMM dd, yyyy').format(logs.last.date) : 'Baseline',
                                style: TextStyle(color: context.mutedColor, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.elevatedSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Change', style: TextStyle(color: context.subtitleColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  color: delta <= 0 ? AppColors.primary : AppColors.accent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'from ${initialWeight.toStringAsFixed(1)} kg',
                                style: TextStyle(color: context.mutedColor, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.elevatedSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: context.borderLine),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Goal & Category', style: TextStyle(color: context.subtitleColor, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text(
                                activeClient.fitnessGoal,
                                style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'BMI ${activeClient.bmi.toStringAsFixed(1)} • ${activeClient.experienceLevel}',
                                style: TextStyle(color: context.mutedColor, fontSize: 10),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Weight Trend (kg) Graph Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.elevatedSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderLine),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weight Trend (kg)',
                                  style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Recorded biometric progression for ${activeClient.name}',
                                  style: TextStyle(color: context.subtitleColor, fontSize: 11),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${logs.length} weigh-in${logs.length == 1 ? '' : 's'}',
                                style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        SizedBox(
                          height: 180,
                          child: logs.length < 2
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.show_chart_rounded, color: context.mutedColor, size: 36),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Only baseline recorded (${logs.first.weightKg.toStringAsFixed(1)} kg)',
                                        style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 4),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        child: Text(
                                          'Progression curve will automatically render here once ${activeClient.name} logs their 2nd weigh-in in their member portal.',
                                          style: TextStyle(color: context.mutedColor, fontSize: 11),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : _buildFlChart(logs),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Recent Log History Header & Snippets
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Log History (${logs.length})',
                        style: TextStyle(color: context.titleColor, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Text(
                          'Recorded by Member',
                          style: TextStyle(color: context.mutedColor, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ...logs.reversed.take(3).map((log) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.elevatedSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.borderLine),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.scale_rounded, color: AppColors.primary, size: 16),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('MMMM d, yyyy').format(log.date),
                                    style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                                  ),
                                  if ((log.notes ?? '').isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      log.notes!,
                                      style: TextStyle(color: context.subtitleColor, fontSize: 11),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${log.weightKg.toStringAsFixed(1)} kg',
                                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              if (log.bodyFatPercent != null)
                                Text(
                                  '${log.bodyFatPercent!.toStringAsFixed(1)}% BF',
                                  style: TextStyle(color: context.mutedColor, fontSize: 10),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      );
    }

  Widget _buildFlChart(List<ProgressLogEntity> logs) {
    final weights = logs.map((l) => l.weightKg).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);
    final minY = (minW - 5).clamp(20.0, 300.0).floorToDouble();
    final maxY = (maxW + 5).ceilToDouble();
    final range = maxY - minY;
    final interval = range > 40 ? 10.0 : (range > 20 ? 5.0 : (range > 10 ? 2.0 : 1.0));

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (val) => FlLine(
            color: AppColors.border.withValues(alpha: 0.6),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: interval,
              getTitlesWidget: (val, meta) => Text(
                '${val.toInt()}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (val, meta) {
                final index = val.toInt();
                if (index >= 0 && index < logs.length) {
                  return Text(
                    DateFormat('M/d').format(logs[index].date),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.elevatedSurface,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.spotIndex;
                final log = logs[idx];
                return LineTooltipItem(
                  '${DateFormat('MMM d').format(log.date)}\n${spot.y.toStringAsFixed(1)} kg',
                  const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              logs.length,
              (i) => FlSpot(i.toDouble(), logs[i].weightKg),
            ),
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.primary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayWorkoutAccomplishmentCard({
    required UserModel activeClient,
    required WorkoutPlanModel? workout,
    required bool hasCoachPlan,
    required String? planName,
    required bool isDayPass,
    required List<String> allDayTags,
    required String? activeDay,
    required List<ExerciseEntity> displayedExercises,
    required int completedCount,
    required int totalCount,
    required double progressRatio,
  }) {
    if (isDayPass) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1-Day Pass (Self-Directed Walk-In)',
                    style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${activeClient.name} is on a 1-Day Pass which does not include coach assignment. Their workout is autonomous.',
                    style: TextStyle(color: context.subtitleColor, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Plan & Trackable Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Accomplished Workout",
                        style: TextStyle(
                          color: context.titleColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Live daily workout progress logged by ${activeClient.name}',
                        style: TextStyle(color: context.subtitleColor, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      planName ?? 'Coach Tracked Plan',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (workout == null || workout.exercises.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderLine),
              ),
              child: Column(
                children: [
                  Icon(Icons.fitness_center_outlined, color: context.mutedColor, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'No workout routine assigned yet for ${activeClient.name}',
                    style: TextStyle(color: context.subtitleColor, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  CustomButton(
                    text: 'Generate AI Workout Routine',
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () async {
                      await ref.read(coachNotifierProvider.notifier).generateWorkoutForClient(activeClient);
                      _fetchClientProgress(activeClient);
                    },
                  ),
                ],
              ),
            ),
          ] else ...[
            // Routine Title and Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.elevatedSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          workout.splitTitle,
                          style: TextStyle(color: context.titleColor, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: (completedCount == totalCount && totalCount > 0
                                  ? AppColors.primary
                                  : (completedCount > 0 ? AppColors.accent : context.cardColor))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: completedCount == totalCount && totalCount > 0
                                ? AppColors.primary
                                : (completedCount > 0 ? AppColors.accent : context.borderLine),
                          ),
                        ),
                        child: Text(
                          completedCount == totalCount && totalCount > 0
                              ? '✓ ALL COMPLETED'
                              : (completedCount > 0 ? '⚡ IN PROGRESS' : '⏳ NOT STARTED'),
                          style: TextStyle(
                            color: completedCount == totalCount && totalCount > 0
                                ? AppColors.primary
                                : (completedCount > 0 ? AppColors.accent : context.mutedColor),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Session Progress Counter & Progress Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session Progress: $completedCount of $totalCount exercises completed today',
                        style: TextStyle(color: context.subtitleColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${(progressRatio * 100).toInt()}%',
                        style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      minHeight: 7,
                      backgroundColor: context.cardColor,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        completedCount == totalCount && totalCount > 0
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Day Split Tabs (if multi-day split)
            if (allDayTags.length > 1) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allDayTags.map((tag) {
                    final isSelected = tag == activeDay;
                    final dayExs = workout.exercises.where((e) => e.dayTag == tag).toList();
                    final dayDone = dayExs.where((e) => e.isCompleted).length;
                    final isDayAllDone = dayExs.isNotEmpty && dayDone == dayExs.length;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedWorkoutDayTag = tag;
                          });
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : context.cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : context.borderLine,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDayAllDone ? Icons.check_circle_rounded : Icons.calendar_today_rounded,
                                size: 13,
                                color: isSelected ? Colors.black : (isDayAllDone ? AppColors.primary : context.mutedColor),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tag,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : context.titleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.black.withValues(alpha: 0.15) : context.elevatedSurface,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '$dayDone/${dayExs.length}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : context.subtitleColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Accomplished Exercises Section
            if (completedCount > 0) ...[
              const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 15),
                  SizedBox(width: 6),
                  Text(
                    'Accomplished Today:',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...displayedExercises.where((e) => e.isCompleted).map((ex) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: TextStyle(
                                color: context.titleColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (ex.dayTag.isNotEmpty)
                                  _buildMiniBadge(ex.dayTag, AppColors.accent),
                                _buildMiniBadge(ex.muscleGroup, AppColors.accentCyan),
                                _buildMiniBadge('${ex.sets} sets × ${ex.reps}', context.subtitleColor),
                                _buildMiniBadge(ex.equipment, context.mutedColor),
                              ],
                            ),
                            if ((ex.instructions ?? '').isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                ex.instructions!,
                                style: TextStyle(color: context.mutedColor, fontSize: 10, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 11, color: Colors.black),
                            SizedBox(width: 3),
                            Text(
                              'ACCOMPLISHED',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            // Remaining / Pending Exercises Section
            if (displayedExercises.any((e) => !e.isCompleted)) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.pending_actions_rounded, color: context.subtitleColor, size: 15),
                  const SizedBox(width: 6),
                  Text(
                    'Remaining for Session (${totalCount - completedCount}):',
                    style: TextStyle(
                      color: context.subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...displayedExercises.where((e) => !e.isCompleted).map((ex) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.elevatedSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.borderLine),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.radio_button_unchecked_rounded, color: context.mutedColor, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ex.name,
                              style: TextStyle(
                                color: context.titleColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                if (ex.dayTag.isNotEmpty)
                                  _buildMiniBadge(ex.dayTag, context.mutedColor),
                                _buildMiniBadge(ex.muscleGroup, context.subtitleColor),
                                _buildMiniBadge('${ex.sets} sets × ${ex.reps}', context.subtitleColor),
                                _buildMiniBadge(ex.equipment, context.mutedColor),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: context.cardColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.borderLine),
                        ),
                        child: Text(
                          'PENDING',
                          style: TextStyle(
                            color: context.mutedColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],

            if (completedCount == totalCount && totalCount > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.2),
                      context.cardColor,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Full workout session accomplished! ${activeClient.name} completed all $totalCount exercises today.',
                        style: TextStyle(color: context.titleColor, fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildClientCard(UserModel c, CoachState coachState, UserEntity? user) {
    final workout = coachState.clientWorkouts[c.id];
    final meal = coachState.clientMeals[c.id];
    final isTrackingActive = _selectedProgressClientId == c.id;

    return InkWell(
      onTap: () => _selectAndTrackClient(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTrackingActive ? AppColors.primary : context.borderLine,
            width: isTrackingActive ? 1.6 : 1,
          ),
          boxShadow: isTrackingActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.accent.withValues(alpha: 0.2),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                    style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (isTrackingActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TRACKING',
                                style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'Goal: ${c.fitnessGoal} • ${c.experienceLevel}',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (workout?.isCoachApproved == true)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✓ Workout',
                          style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    if (meal?.isCoachApproved == true)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✓ Meal',
                          style: TextStyle(color: AppColors.accentCyan, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          workout?.splitTitle ?? 'Tap to track biometrics or inspect',
                          style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (workout != null && workout.exercises.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (_) {
                          final done = workout.exercises.where((e) => e.isCompleted).length;
                          final total = workout.exercises.length;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (done > 0 ? AppColors.primary : context.elevatedSurface).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: done > 0 ? AppColors.primary.withValues(alpha: 0.4) : context.borderLine,
                              ),
                            ),
                            child: Text(
                              '$done/$total Accomplished',
                              style: TextStyle(
                                color: done > 0 ? AppColors.primary : context.mutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        backgroundColor: isTrackingActive
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : context.elevatedSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _selectAndTrackClient(c),
                      icon: const Icon(Icons.insights_rounded, size: 13, color: AppColors.primary),
                      label: const Text('Track', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 6),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        backgroundColor: context.elevatedSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showClientDetails(context, ref, c, workout, meal),
                      icon: const Icon(Icons.chevron_right, size: 14, color: AppColors.accent),
                      label: const Text('Review', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherMemberCard(UserModel c, CoachState coachState, UserEntity? user) {
    final workout = coachState.clientWorkouts[c.id] ?? LocalCacheService().getWorkoutPlan(c.id);
    final meal = coachState.clientMeals[c.id] ?? LocalCacheService().getMealPlan(c.id);
    final isUnassigned = c.assignedCoachId == null || c.assignedCoachId!.isEmpty;
    final isTrackingActive = _selectedProgressClientId == c.id;

    final mem = LocalCacheService().getMembership(c.id);
    final isDayPass = mem != null && (mem.planName.toLowerCase().contains('day') || mem.planName.toLowerCase().contains('walk'));

    return InkWell(
      onTap: () => _selectAndTrackClient(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isTrackingActive
                ? AppColors.primary
                : (isDayPass
                    ? Colors.amber.withValues(alpha: 0.3)
                    : (isUnassigned ? AppColors.accent.withValues(alpha: 0.4) : context.borderLine)),
            width: isTrackingActive ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: (isDayPass
                          ? Colors.amber
                          : (isUnassigned ? AppColors.accent : AppColors.primary))
                      .withValues(alpha: 0.2),
                  child: Text(
                    c.name.isNotEmpty ? c.name[0].toUpperCase() : 'M',
                    style: TextStyle(
                      color: isDayPass
                          ? Colors.amber
                          : (isUnassigned ? AppColors.accent : AppColors.primary),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              c.name,
                              style: TextStyle(color: context.titleColor, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                          ),
                          if (isTrackingActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'TRACKING',
                                style: TextStyle(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c.age > 0 ? '${c.age}yo • ' : ''}${c.gender.isNotEmpty ? '${c.gender} • ' : ''}${c.fitnessGoal} • ${c.experienceLevel}',
                        style: TextStyle(color: context.subtitleColor, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDayPass
                        ? Colors.amber.withValues(alpha: 0.15)
                        : (isUnassigned ? AppColors.accent : Colors.deepPurpleAccent).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isDayPass
                        ? '1-Day Pass (Self-Directed)'
                        : (isUnassigned ? 'Unassigned' : 'Other Coach'),
                    style: TextStyle(
                      color: isDayPass
                          ? Colors.amber
                          : (isUnassigned ? AppColors.accent : Colors.deepPurpleAccent),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          workout?.splitTitle ?? (isDayPass ? '1-Day Full Body Express Routine' : 'No workout routine assigned'),
                          style: TextStyle(color: context.mutedColor, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (workout != null && workout.exercises.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Builder(builder: (_) {
                          final done = workout.exercises.where((e) => e.isCompleted).length;
                          final total = workout.exercises.length;
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (done > 0 ? AppColors.primary : context.elevatedSurface).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: done > 0 ? AppColors.primary.withValues(alpha: 0.4) : context.borderLine,
                              ),
                            ),
                            child: Text(
                              '$done/$total Accomplished',
                              style: TextStyle(
                                color: done > 0 ? AppColors.primary : context.mutedColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        backgroundColor: isTrackingActive
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : context.elevatedSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _selectAndTrackClient(c),
                      icon: const Icon(Icons.insights_rounded, size: 13, color: AppColors.primary),
                      label: const Text('Track', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    if (isUnassigned && !isDayPass) ...[
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _assignClientToMe(c, user),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 14, color: AppColors.accent),
                        label: const Text('Assign to Me', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        backgroundColor: context.elevatedSurface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () => _showClientDetails(context, ref, c, workout, meal),
                      icon: Icon(Icons.visibility_outlined, size: 14, color: context.titleColor),
                      label: Text('View Profile', style: TextStyle(color: context.titleColor, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachStat extends StatelessWidget {
  final String value;
  final String label;

  const _CoachStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(color: context.titleColor, fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: context.subtitleColor, fontSize: 11),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final String label;
  final String value;

  const _InfoBadge({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.elevatedSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.borderLine),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: context.mutedColor, fontSize: 10)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: context.titleColor, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
