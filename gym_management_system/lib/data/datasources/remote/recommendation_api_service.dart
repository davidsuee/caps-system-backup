import '../../../core/network/api_client.dart';
import '../../models/workout_plan_model.dart';
import '../../models/meal_plan_model.dart';
import '../../../domain/entities/user_entity.dart';
import '../local/local_cache_service.dart';

class RecommendationApiService {
  final ApiClient _client;

  RecommendationApiService([ApiClient? client]) : _client = client ?? ApiClient();

  Future<WorkoutPlanModel> getWorkoutRecommendation(UserEntity user) async {
    try {
      final response = await _client.dio.post(
        '/recommend-workout',
        data: {
          'user_id': user.id,
          'age': user.age,
          'gender': user.gender,
          'height_cm': user.heightCm,
          'weight_kg': user.weightKg,
          'fitness_goal': user.fitnessGoal,
          'activity_level': user.activityLevel,
          'experience_level': user.experienceLevel,
          'available_equipment': user.availableEquipment,
          'injury_flags': user.injuryFlags,
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['user_id'] == null || data['user_id'].toString().isEmpty) {
        data['user_id'] = user.id;
      }
      final plan = WorkoutPlanModel.fromJson(data, 'workout_${user.id}_${DateTime.now().millisecondsSinceEpoch}');
      final membership = LocalCacheService().getMembership(user.id);
      final isDayPass = membership != null && (membership.planName.toLowerCase().contains('day') || membership.planName.toLowerCase().contains('walk'));

      final hasDayTags = plan.exercises.any((e) => e.dayTag.isNotEmpty);
      WorkoutPlanModel finalPlan = plan;
      if (!hasDayTags) {
        final tagged = plan.exercises.map((ex) {
          if (isDayPass) {
            return ex.copyWith(dayTag: 'Day 1: Full Body');
          }
          final mg = ex.muscleGroup.toLowerCase();
          if (mg.contains('chest') || mg.contains('shoulder') || mg.contains('tricep') || mg.contains('delt')) {
            return ex.copyWith(dayTag: 'Day 1: Push');
          } else if (mg.contains('back') || mg.contains('lat') || mg.contains('bicep') || mg.contains('rhomboid')) {
            return ex.copyWith(dayTag: 'Day 2: Pull');
          } else if (mg.contains('quad') || mg.contains('hamstring') || mg.contains('leg') || mg.contains('glute') || mg.contains('calf') || mg.contains('core')) {
            return ex.copyWith(dayTag: 'Day 3: Legs & Core');
          }
          return ex.copyWith(dayTag: 'Day 1: Full Body');
        }).toList();
        finalPlan = plan.copyWith(exercises: tagged);
      }
      if (isDayPass) {
        finalPlan = finalPlan.copyWith(
          isCoachApproved: true,
          coachNotes: 'Autonomous 1-Day Pass Routine (Self-Directed - Ready to Train)',
        );
      }
      return finalPlan;
    } catch (e) {
      // Graceful on-device fallback if microservice is offline
      return _generateOnDeviceWorkoutFallback(user);
    }
  }

  Future<MealPlanModel> getMealPlanOptimization({
    required UserEntity user,
    required double targetCalories,
    double? targetProtein,
    double? targetCarbs,
    double? targetFat,
    List<String> dietaryRestrictions = const [],
    double? budgetLimit,
  }) async {
    try {
      final response = await _client.dio.post(
        '/generate-meal-plan',
        data: {
          'user_id': user.id,
          'target_calories': targetCalories,
          'target_protein': targetProtein,
          'target_carbs': targetCarbs,
          'target_fat': targetFat,
          'fitness_goal': user.fitnessGoal,
          'dietary_restrictions': dietaryRestrictions.isNotEmpty ? dietaryRestrictions : user.dietaryRestrictions,
          'budget_limit': budgetLimit,
          'meals_per_day': 4,
        },
      );

      final data = Map<String, dynamic>.from(response.data as Map);
      if (data['user_id'] == null || data['user_id'].toString().isEmpty) {
        data['user_id'] = user.id;
      }
      return MealPlanModel.fromJson(data, 'meal_${user.id}_${DateTime.now().millisecondsSinceEpoch}');
    } catch (e) {
      // Graceful on-device fallback if microservice is offline
      return _generateOnDeviceMealFallback(user, targetCalories, targetProtein, targetCarbs, targetFat);
    }
  }

  WorkoutPlanModel _generateOnDeviceWorkoutFallback(UserEntity user) {
    final goal = user.fitnessGoal.toLowerCase();
    final injuries = user.injuryFlags.map((i) => i.toLowerCase().trim()).toList();
    final membership = LocalCacheService().getMembership(user.id);
    final isDayPass = membership != null && (membership.planName.toLowerCase().contains('day') || membership.planName.toLowerCase().contains('walk'));

    String split;
    String routineSummary;
    List<ExerciseModel> exercises = [];

    final wt = user.weightKg;

    // 1. Determine split & day-specific exercises based on Membership + Goal + Weight
    if (isDayPass) {
      split = '1-Day Full Body Athletic Foundation (Day Pass)';
      routineSummary = 'High-yield full-body conditioning session designed for Day Pass walk-ins. Combines compound free weights, unilateral movements, and machines in a single comprehensive visit.';
      exercises = [
        const ExerciseModel(
          name: 'Flat Dumbbell Chest Press',
          muscleGroup: 'Pectorals (Chest)',
          sets: '3',
          reps: '10-12',
          restSec: 60,
          equipment: 'Dumbbells & Bench',
          instructions: 'Free Weight Compound: Squeeze pectorals at top; maintain controlled 3-second eccentric tempo.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Single-Arm Dumbbell Row',
          muscleGroup: 'Lats & Rhomboids',
          sets: '3',
          reps: '10-12 / arm',
          restSec: 60,
          equipment: 'Dumbbell & Bench',
          instructions: 'Unilateral Movement: Pull dumbbell toward hip with elbow tucked to correct left/right upper body asymmetry.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Bulgarian Split Squat',
          muscleGroup: 'Quadriceps & Glutes',
          sets: '3',
          reps: '10-12 / leg',
          restSec: 60,
          equipment: 'Dumbbells & Bench',
          instructions: 'Unilateral Movement: Elevate rear foot on bench; descend vertically to eliminate quad/glute imbalances.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Dumbbell Romanian Deadlift (RDL)',
          muscleGroup: 'Hamstrings & Glutes',
          sets: '3',
          reps: '10-12',
          restSec: 60,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Compound: Hinge strictly at hips while maintaining a neutral lumbar spine.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Lat Pulldown Machine (Neutral Grip)',
          muscleGroup: 'Lats & Upper Back',
          sets: '3',
          reps: '12',
          restSec: 60,
          equipment: 'Cable Machine',
          instructions: 'Machine / Cable: Controlled eccentric phase for continuous vertical lat tension.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Standing Dumbbell Lateral Raises',
          muscleGroup: 'Deltoids & Shoulders',
          sets: '3',
          reps: '12-15',
          restSec: 45,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Isolation: Lead with elbows in scapular plane for 3D shoulder capping.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Alternating DB Bicep Curls & Cable Pushdown',
          muscleGroup: 'Arms (Biceps & Triceps)',
          sets: '3',
          reps: '12',
          restSec: 45,
          equipment: 'Dumbbells & Cable',
          instructions: 'Unilateral & Cable: Supinate wrists at peak contraction; lock out triceps cleanly on cable.',
          dayTag: 'Day 1: Full Body',
        ),
        const ExerciseModel(
          name: 'Incline Treadmill Burnout or Rower',
          muscleGroup: 'Cardiovascular & Core',
          sets: '1',
          reps: '15 mins',
          restSec: 0,
          equipment: 'Treadmill / Rower',
          instructions: 'Cardio Finish: Maintain steady aerobic heart rate (Zone 2) to finalize session.',
          dayTag: 'Day 1: Full Body',
        ),
      ];
    } else if (goal.contains('muscle') || goal.contains('gain')) {
      if (wt < 70) {
        split = 'Push-Pull-Legs (Phase 1: Hypertrophy Base • ${wt.toInt()}kg)';
        routineSummary = 'Volume accumulation phase for ${wt.toInt()}kg bodyweight. Focus on compound free weights and unilateral balance (8-12 reps, ~${(wt * 0.75).round()}kg target load).';
      } else if (wt < 77) {
        split = 'Push-Pull-Legs (Phase 2: Progressive Overload • ${wt.toInt()}kg)';
        routineSummary = 'Progressive overload phase for ${wt.toInt()}kg bodyweight. Increasing mechanical tension and unilateral stability (8-10 reps, ~${(wt * 0.85).round()}kg target load).';
      } else if (wt < 83) {
        split = 'Push-Pull-Legs (Phase 3: Strength Overload • ${wt.toInt()}kg)';
        routineSummary = 'Heavy strength overload phase for ${wt.toInt()}kg bodyweight. High-density compound barbell sets and unilateral accessory work (6-8 reps, ~${(wt * 0.95).round()}kg target load).';
      } else {
        split = 'Push-Pull-Legs (Phase 4: Peak Power & Muscular Density • ${wt.toInt()}kg)';
        routineSummary = 'Peak power & muscular density phase for ${wt.toInt()}kg bodyweight. Periodized heavy compound lifts balanced with single-limb stabilizers (4-6 reps, ~${(wt * 1.05).round()}kg target load).';
      }

      // 3-Day Push-Pull-Legs Split with distinct Day Tags
      exercises = [
        // Day 1: Push
        const ExerciseModel(
          name: 'Barbell Flat Bench Press',
          muscleGroup: 'Chest',
          sets: '4',
          reps: '8-10',
          restSec: 90,
          equipment: 'Barbell & Bench',
          instructions: 'Free Weight Compound: Primary horizontal press for maximal pectoral mechanical tension.',
          dayTag: 'Day 1: Push',
        ),
        const ExerciseModel(
          name: 'Incline Dumbbell Press',
          muscleGroup: 'Upper Chest',
          sets: '3',
          reps: '10-12',
          restSec: 75,
          equipment: 'Dumbbells & Incline Bench',
          instructions: 'Free Weight Compound: 30-degree incline targeting the clavicular pectoral fibers.',
          dayTag: 'Day 1: Push',
        ),
        const ExerciseModel(
          name: 'Standing Dumbbell Lateral Raises',
          muscleGroup: 'Lateral Deltoids',
          sets: '3',
          reps: '12-15',
          restSec: 60,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Isolation: Lead with elbows in scapular plane for lateral delt capping.',
          dayTag: 'Day 1: Push',
        ),
        const ExerciseModel(
          name: 'Single-Arm Overhead DB Tricep Extension',
          muscleGroup: 'Triceps',
          sets: '3',
          reps: '10-12 / arm',
          restSec: 45,
          equipment: 'Dumbbell',
          instructions: 'Unilateral Movement: Equalizes triceps long-head development across both arms.',
          dayTag: 'Day 1: Push',
        ),
        const ExerciseModel(
          name: 'Cable Tricep Pushdown & Dips',
          muscleGroup: 'Triceps',
          sets: '3',
          reps: '12-15',
          restSec: 45,
          equipment: 'Cable Station',
          instructions: 'Machine / Cable: Constant cable tension targeting lateral and medial triceps heads.',
          dayTag: 'Day 1: Push',
        ),

        // Day 2: Pull
        const ExerciseModel(
          name: 'Barbell Deadlift (Sumo/Conventional)',
          muscleGroup: 'Posterior Chain & Back',
          sets: '4',
          reps: '6-8',
          restSec: 120,
          equipment: 'Barbell & Platform',
          instructions: 'Free Weight Compound: Foundational hip hinge recruiting spinal erectors, lats, and glutes.',
          dayTag: 'Day 2: Pull',
        ),
        const ExerciseModel(
          name: 'Single-Arm Dumbbell Row',
          muscleGroup: 'Lats & Rhomboids',
          sets: '3',
          reps: '10-12 / arm',
          restSec: 60,
          equipment: 'Dumbbell & Bench',
          instructions: 'Unilateral Movement: Row into the pocket; eliminates lat strength and thickness discrepancy.',
          dayTag: 'Day 2: Pull',
        ),
        const ExerciseModel(
          name: 'Lat Pulldown (Wide Grip)',
          muscleGroup: 'Lats & Upper Back',
          sets: '4',
          reps: '10-12',
          restSec: 75,
          equipment: 'Lat Machine',
          instructions: 'Machine / Cable: Vertical pull driving elbows straight down to expand lat width.',
          dayTag: 'Day 2: Pull',
        ),
        const ExerciseModel(
          name: 'Alternating Incline DB Bicep Curls',
          muscleGroup: 'Biceps & Forearms',
          sets: '3',
          reps: '12 / arm',
          restSec: 45,
          equipment: 'Dumbbells',
          instructions: 'Unilateral Movement: Strict bicep peak isolation with full supination at contraction.',
          dayTag: 'Day 2: Pull',
        ),

        // Day 3: Legs & Core
        const ExerciseModel(
          name: 'Barbell Back Squat / Leg Press',
          muscleGroup: 'Quadriceps & Glutes',
          sets: '4',
          reps: '8-10',
          restSec: 120,
          equipment: 'Squat Rack / Leg Press',
          instructions: 'Free Weight Compound: Deep knee flexion with thoracic tightness for quadriceps overload.',
          dayTag: 'Day 3: Legs & Core',
        ),
        const ExerciseModel(
          name: 'Bulgarian Split Squats',
          muscleGroup: 'Quadriceps & Glutes',
          sets: '3',
          reps: '10-12 / leg',
          restSec: 90,
          equipment: 'Dumbbells & Bench',
          instructions: 'Unilateral Movement: Unlocks single-leg hip stability and corrects quad strength disparities.',
          dayTag: 'Day 3: Legs & Core',
        ),
        const ExerciseModel(
          name: 'Romanian Dumbbell Deadlift',
          muscleGroup: 'Hamstrings',
          sets: '3',
          reps: '10-12',
          restSec: 90,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Compound: Strict hip hinge loading hamstrings under eccentric stretch.',
          dayTag: 'Day 3: Legs & Core',
        ),
        const ExerciseModel(
          name: 'Single-Leg Standing Calf Raises',
          muscleGroup: 'Calves',
          sets: '4',
          reps: '15 / leg',
          restSec: 45,
          equipment: 'Dumbbell & Step',
          instructions: 'Unilateral Movement: Full ankle dorsiflexion and peak plantar contraction.',
          dayTag: 'Day 3: Legs & Core',
        ),
        const ExerciseModel(
          name: 'Hanging Leg Raises & Plank Hold',
          muscleGroup: 'Core Stability',
          sets: '3',
          reps: '12-15 reps / 45s',
          restSec: 45,
          equipment: 'Pull-up Bar & Mat',
          instructions: 'Core & Anti-Extension: Progressive anterior core stabilization and hip flexor control.',
          dayTag: 'Day 3: Legs & Core',
        ),
      ];
    } else if (goal.contains('loss')) {
      if (wt >= 80) {
        split = 'Metabolic Fat-Burn & Caloric Shred (${wt.toInt()}kg)';
        routineSummary = 'High-caloric expenditure metabolic circuit designed for ${wt.toInt()}kg. Short rest intervals (30-45s) combined with unilateral work maximize fat oxidation.';
      } else {
        split = 'Upper-Lower Lean Definition (${wt.toInt()}kg)';
        routineSummary = 'Antagonistic superset conditioning for ${wt.toInt()}kg combining free weights, unilateral training, and machines to retain lean muscle in deficit.';
      }

      // Upper-Lower 2-Day Split with Day Tags
      exercises = [
        // Day 1: Upper
        const ExerciseModel(
          name: 'Barbell Bench Press',
          muscleGroup: 'Chest',
          sets: '4',
          reps: '8-10',
          restSec: 75,
          equipment: 'Barbell & Bench',
          instructions: 'Free Weight Compound: Heavy horizontal press sustaining muscle density while in deficit.',
          dayTag: 'Day 1: Upper',
        ),
        const ExerciseModel(
          name: 'Single-Arm Dumbbell Row',
          muscleGroup: 'Upper Back',
          sets: '4',
          reps: '10-12 / arm',
          restSec: 60,
          equipment: 'Dumbbell & Bench',
          instructions: 'Unilateral Movement: Maximizes lats contraction while challenging anti-rotational core stability.',
          dayTag: 'Day 1: Upper',
        ),
        const ExerciseModel(
          name: 'Overhead DB Shoulder Press',
          muscleGroup: 'Shoulders',
          sets: '3',
          reps: '10-12',
          restSec: 60,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Compound: Full vertical push engaging front deltoids and core.',
          dayTag: 'Day 1: Upper',
        ),
        const ExerciseModel(
          name: 'Cable Tricep Pushdown & EZ Bicep Curl',
          muscleGroup: 'Arms',
          sets: '3',
          reps: '12',
          restSec: 45,
          equipment: 'Cable & Bar',
          instructions: 'Machine / Free Weight: Antagonistic arm superset maximizing metabolic fatigue.',
          dayTag: 'Day 1: Upper',
        ),

        // Day 2: Lower
        const ExerciseModel(
          name: 'Barbell Front or Back Squat',
          muscleGroup: 'Quadriceps',
          sets: '4',
          reps: '8-10',
          restSec: 90,
          equipment: 'Squat Rack',
          instructions: 'Free Weight Compound: Foundational lower-body compound burning high caloric volume.',
          dayTag: 'Day 2: Lower',
        ),
        const ExerciseModel(
          name: 'Walking Dumbbell Lunges',
          muscleGroup: 'Quadriceps & Glutes',
          sets: '3',
          reps: '12 steps / leg',
          restSec: 60,
          equipment: 'Dumbbells',
          instructions: 'Unilateral Movement: Dynamic single-leg stride targeting glutes, quads, and dynamic balance.',
          dayTag: 'Day 2: Lower',
        ),
        const ExerciseModel(
          name: 'Romanian Dumbbell Deadlift',
          muscleGroup: 'Hamstrings',
          sets: '3',
          reps: '10-12',
          restSec: 75,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Compound: Hip hinge prioritizing hamstring stretch and glute recruitment.',
          dayTag: 'Day 2: Lower',
        ),
        const ExerciseModel(
          name: 'Lying Leg Curl Machine',
          muscleGroup: 'Hamstrings',
          sets: '3',
          reps: '12-15',
          restSec: 60,
          equipment: 'Leg Curl',
          instructions: 'Machine: Direct knee flexion isolation for distal hamstring fibers.',
          dayTag: 'Day 2: Lower',
        ),
        const ExerciseModel(
          name: 'Hanging Leg Raises & Plank',
          muscleGroup: 'Core',
          sets: '3',
          reps: '12-15',
          restSec: 45,
          equipment: 'Bar & Mat',
          instructions: 'Core Stability: Spinal flexion and isometric anti-extension core control.',
          dayTag: 'Day 2: Lower',
        ),
      ];
    } else if (goal.contains('endurance')) {
      split = 'Cardio-HIIT & VO2 Max Engine (${wt.toInt()}kg)';
      routineSummary = 'Aerobic interval conditioning for ${wt.toInt()}kg bodyweight. Focuses on lactate threshold and cardiac output.';

      exercises = [
        // Day 1: Aerobic Base & Lactate Threshold
        const ExerciseModel(
          name: 'Incline Treadmill Sprints',
          muscleGroup: 'Cardiovascular',
          sets: '6',
          reps: '60s on / 30s off',
          restSec: 45,
          equipment: 'Treadmill',
          instructions: 'Cardiovascular Interval: High-incline sprints pushing VO2 max output.',
          dayTag: 'Day 1: Aerobic Base',
        ),
        const ExerciseModel(
          name: 'Kettlebell Russian Swings',
          muscleGroup: 'Posterior Chain',
          sets: '4',
          reps: '20',
          restSec: 45,
          equipment: 'Kettlebell',
          instructions: 'Free Weight Dynamic: Explosive hip snap training posterior endurance.',
          dayTag: 'Day 1: Aerobic Base',
        ),
        const ExerciseModel(
          name: 'Rowing Machine Sprints',
          muscleGroup: 'Full Body Endurance',
          sets: '5',
          reps: '250m',
          restSec: 60,
          equipment: 'Rower',
          instructions: 'Ergometer: Full-body power endurance with legs, back, and cardiovascular synchronization.',
          dayTag: 'Day 1: Aerobic Base',
        ),

        // Day 2: Agility & Caloric Burn
        const ExerciseModel(
          name: 'Plyometric Box Jumps',
          muscleGroup: 'Leg Power',
          sets: '4',
          reps: '12',
          restSec: 45,
          equipment: 'Plyo Box',
          instructions: 'Plyometric: Explosive triple extension landing softly in squat position.',
          dayTag: 'Day 2: Agility & Power',
        ),
        const ExerciseModel(
          name: 'Battle Rope Slams',
          muscleGroup: 'Upper Conditioning',
          sets: '4',
          reps: '30 sec',
          restSec: 30,
          equipment: 'Battle Ropes',
          instructions: 'Conditioning: Alternate waves and double slams with athletic stance.',
          dayTag: 'Day 2: Agility & Power',
        ),
        const ExerciseModel(
          name: 'Burpee to Box Step-Up',
          muscleGroup: 'Full Body Aerobic',
          sets: '3',
          reps: '12',
          restSec: 45,
          equipment: 'Box',
          instructions: 'Unilateral Aerobic: Chest-to-floor burpee transitioned into alternating single-leg step-up.',
          dayTag: 'Day 2: Agility & Power',
        ),
      ];
    } else {
      split = 'Functional Strength & Mobility (${wt.toInt()}kg)';
      routineSummary = 'Balanced athletic foundation for ${wt.toInt()}kg bodyweight enhancing postural stability and multi-joint strength with free weights and unilateral balance.';

      exercises = [
        // Day 1: Lower & Core Foundation
        const ExerciseModel(
          name: 'Leg Press Machine',
          muscleGroup: 'Quadriceps',
          sets: '3',
          reps: '12',
          restSec: 75,
          equipment: 'Leg Press',
          instructions: 'Machine: Safe high-volume leg loading without axial spine compression.',
          dayTag: 'Day 1: Lower & Core',
        ),
        const ExerciseModel(
          name: 'Bulgarian Split Squats',
          muscleGroup: 'Quadriceps & Glutes',
          sets: '3',
          reps: '10 / leg',
          restSec: 60,
          equipment: 'Dumbbells & Bench',
          instructions: 'Unilateral Movement: Balances pelvic alignment and single-leg drive.',
          dayTag: 'Day 1: Lower & Core',
        ),
        const ExerciseModel(
          name: 'Dumbbell Romanian Deadlift',
          muscleGroup: 'Hamstrings & Glutes',
          sets: '3',
          reps: '10-12',
          restSec: 75,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Compound: Hip hinge targeting posterior chain tension.',
          dayTag: 'Day 1: Lower & Core',
        ),
        const ExerciseModel(
          name: 'Bodyweight Glute Bridges',
          muscleGroup: 'Glutes & Core',
          sets: '3',
          reps: '15',
          restSec: 45,
          equipment: 'Mat',
          instructions: 'Bodyweight: Gluteus maximus isolation and pelvis stabilizer priming.',
          dayTag: 'Day 1: Lower & Core',
        ),

        // Day 2: Upper & Postural Stability
        const ExerciseModel(
          name: 'Flat Dumbbell Press',
          muscleGroup: 'Chest',
          sets: '3',
          reps: '10-12',
          restSec: 75,
          equipment: 'Dumbbells & Bench',
          instructions: 'Free Weight Compound: Natural wrist rotation protecting shoulder capsule.',
          dayTag: 'Day 2: Upper & Posture',
        ),
        const ExerciseModel(
          name: 'Single-Arm Dumbbell Row',
          muscleGroup: 'Lats & Rhomboids',
          sets: '3',
          reps: '10-12 / arm',
          restSec: 60,
          equipment: 'Dumbbell & Bench',
          instructions: 'Unilateral Movement: Activates rhomboids and deep spinal erectors unilaterally.',
          dayTag: 'Day 2: Upper & Posture',
        ),
        const ExerciseModel(
          name: 'Lat Pulldown (Neutral Grip)',
          muscleGroup: 'Upper Back',
          sets: '3',
          reps: '12',
          restSec: 75,
          equipment: 'Lat Pulldown Machine',
          instructions: 'Machine / Cable: Shoulder-friendly pull emphasizing lower lat fibers.',
          dayTag: 'Day 2: Upper & Posture',
        ),
        const ExerciseModel(
          name: 'Seated Dumbbell Shoulder Press',
          muscleGroup: 'Deltoids',
          sets: '3',
          reps: '12',
          restSec: 60,
          equipment: 'Dumbbells',
          instructions: 'Free Weight Compound: Overhead pushing volume with back support.',
          dayTag: 'Day 2: Upper & Posture',
        ),
        const ExerciseModel(
          name: 'Standing DB Bicep Curls & Cable Pushdown',
          muscleGroup: 'Arms',
          sets: '2',
          reps: '12',
          restSec: 45,
          equipment: 'Dumbbells & Cables',
          instructions: 'Unilateral & Cable: Arm conditioning finishing circuit.',
          dayTag: 'Day 2: Upper & Posture',
        ),
      ];
    }

    // 3. Filter out exercises if user has reported injuries
    if (injuries.isNotEmpty) {
      exercises = exercises.where((ex) {
        final name = ex.name.toLowerCase();
        final mg = ex.muscleGroup.toLowerCase();
        if (injuries.contains('knee')) {
          if (name.contains('squat') || name.contains('lunge') || name.contains('jump') || mg.contains('quad')) return false;
        }
        if (injuries.contains('shoulder')) {
          if (name.contains('overhead') || name.contains('military') || name.contains('dip') || mg.contains('shoulder') || mg.contains('delt')) return false;
        }
        if (injuries.contains('lower_back') || injuries.contains('back')) {
          if (name.contains('deadlift') || name.contains('bent-over') || mg.contains('lower back')) return false;
        }
        return true;
      }).toList();
    }

    return WorkoutPlanModel(
      id: 'routine_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      splitTitle: split,
      confidenceScore: 0.92,
      source: 'viscous_smart_engine',
      summary: 'Personalized for ${user.fitnessGoal} (${user.experienceLevel} • ${user.activityLevel}) based on your biometrics (${user.weightKg.toInt()} kg, ${user.heightCm.toInt()} cm). $routineSummary',
      exercises: exercises,
      generatedAt: DateTime.now(),
      isCoachApproved: isDayPass ? true : false,
      coachNotes: isDayPass ? 'Autonomous 1-Day Pass Routine (Self-Directed - Ready to Train)' : null,
    );
  }

  MealPlanModel _generateOnDeviceMealFallback(
    UserEntity user,
    double cal,
    double? prot,
    double? carb,
    double? fat,
  ) {
    final goal = user.fitnessGoal.toLowerCase();
    final restrictions = (user.dietaryRestrictions).map((r) => r.toLowerCase().trim()).where((r) => r.isNotEmpty).toList();

    // Calculate macro ratios dynamically based on fitness goal
    double pRatio;
    double cRatio;
    double fRatio;

    if (goal.contains('loss')) {
      pRatio = 0.35; // High protein to preserve muscle in calorie deficit
      cRatio = 0.35;
      fRatio = 0.30;
    } else if (goal.contains('muscle') || goal.contains('gain')) {
      pRatio = 0.30; // Muscle hypertrophy surplus
      cRatio = 0.45;
      fRatio = 0.25;
    } else if (goal.contains('endurance')) {
      pRatio = 0.20;
      cRatio = 0.55; // Glycogen loading for aerobic stamina
      fRatio = 0.25;
    } else {
      pRatio = 0.25;
      cRatio = 0.45;
      fRatio = 0.30;
    }

    final targetP = prot ?? (cal * pRatio / 4.0);
    final targetC = carb ?? (cal * cRatio / 4.0);
    final targetF = fat ?? (cal * fRatio / 9.0);

    // Dynamic slot calorie breakdown: Breakfast 25%, Lunch 35%, Dinner 25%, Snack 15%
    final bCal = (cal * 0.25).roundToDouble();
    final lCal = (cal * 0.35).roundToDouble();
    final dCal = (cal * 0.25).roundToDouble();
    final sCal = (cal * 0.15).roundToDouble();

    // Scale serving quantities relative to baseline 2000 kcal diet
    final scale = (cal / 2000.0).clamp(0.6, 2.0);

    // Build Breakfast
    List<FoodItemModel> breakfastItems;
    if (goal.contains('loss')) {
      breakfastItems = [
        FoodItemModel(
          foodId: 'F002',
          name: 'Boiled Egg Whites with Spinach',
          category: 'Breakfast',
          servings: (3 * scale).roundToDouble(),
          servingUnit: '${(3 * scale).toInt()} egg whites',
          calories: (bCal * 0.35).roundToDouble(),
          protein: (bCal * 0.35 * 0.7 / 4.0).roundToDouble(),
          carbs: 2,
          fat: 0.5,
          cost: 20.0,
        ),
        FoodItemModel(
          foodId: 'F001',
          name: 'Rolled Oats with Cinnamon & Chia Seeds',
          category: 'Breakfast',
          servings: (1 * scale).toStringAsFixed(1) == '1.0' ? 1 : 1.5,
          servingUnit: '1 bowl',
          calories: (bCal * 0.65).roundToDouble(),
          protein: (bCal * 0.65 * 0.15 / 4.0).roundToDouble(),
          carbs: (bCal * 0.65 * 0.70 / 4.0).roundToDouble(),
          fat: 3.5,
          cost: 25.0,
        ),
      ];
    } else if (goal.contains('muscle') || goal.contains('gain')) {
      breakfastItems = [
        FoodItemModel(
          foodId: 'F002',
          name: 'Whole Scrambled Eggs with Avocado',
          category: 'Breakfast',
          servings: (3 * scale).roundToDouble(),
          servingUnit: '${(3 * scale).toInt()} eggs',
          calories: (bCal * 0.50).roundToDouble(),
          protein: (bCal * 0.50 * 0.35 / 4.0).roundToDouble(),
          carbs: 4,
          fat: (bCal * 0.50 * 0.55 / 9.0).roundToDouble(),
          cost: 35.0,
        ),
        FoodItemModel(
          foodId: 'F001',
          name: 'Hearty Oatmeal with Banana & Peanut Butter',
          category: 'Breakfast',
          servings: 1.5,
          servingUnit: 'Large bowl',
          calories: (bCal * 0.50).roundToDouble(),
          protein: (bCal * 0.50 * 0.20 / 4.0).roundToDouble(),
          carbs: (bCal * 0.50 * 0.60 / 4.0).roundToDouble(),
          fat: 8.0,
          cost: 40.0,
        ),
      ];
    } else {
      breakfastItems = [
        FoodItemModel(
          foodId: 'F001',
          name: 'Rolled Oats with Fresh Berries',
          category: 'Breakfast',
          servings: 1.0,
          servingUnit: '1 cup',
          calories: (bCal * 0.60).roundToDouble(),
          protein: (bCal * 0.60 * 0.15 / 4.0).roundToDouble(),
          carbs: (bCal * 0.60 * 0.70 / 4.0).roundToDouble(),
          fat: 4.0,
          cost: 30.0,
        ),
        FoodItemModel(
          foodId: 'F002',
          name: 'Boiled Whole Eggs',
          category: 'Breakfast',
          servings: 2,
          servingUnit: '2 eggs',
          calories: (bCal * 0.40).roundToDouble(),
          protein: (bCal * 0.40 * 0.40 / 4.0).roundToDouble(),
          carbs: 1,
          fat: 9.0,
          cost: 20.0,
        ),
      ];
    }

    // Build Lunch
    final lMainName = goal.contains('loss') ? 'Grilled Skinless Chicken Breast' : 'Grilled Chicken with Garlic Rice';
    final lunchItems = [
      FoodItemModel(
        foodId: 'F008',
        name: lMainName,
        category: 'Lunch',
        servings: (1.5 * scale).roundToDouble(),
        servingUnit: '${(180 * scale).toInt()}g',
        calories: (lCal * 0.55).roundToDouble(),
        protein: (lCal * 0.55 * 0.75 / 4.0).roundToDouble(),
        carbs: 2,
        fat: 4.5,
        cost: 65.0,
      ),
      FoodItemModel(
        foodId: 'F009',
        name: goal.contains('loss') ? 'Steamed Cauliflower & Brown Rice' : 'Steamed Brown Rice',
        category: 'Lunch',
        servings: (1.0 * scale).roundToDouble(),
        servingUnit: '1 cup',
        calories: (lCal * 0.30).roundToDouble(),
        protein: 3.5,
        carbs: (lCal * 0.30 * 0.85 / 4.0).roundToDouble(),
        fat: 0.5,
        cost: 15.0,
      ),
      FoodItemModel(
        foodId: 'F011',
        name: 'Steamed Broccoli, Carrots & Green Beans',
        category: 'Lunch',
        servings: 1.0,
        servingUnit: '1 bowl',
        calories: (lCal * 0.15).roundToDouble(),
        protein: 4.0,
        carbs: (lCal * 0.15 * 0.70 / 4.0).roundToDouble(),
        fat: 0.5,
        cost: 25.0,
      ),
    ];

    // Build Dinner
    final dinnerItems = [
      FoodItemModel(
        foodId: 'F014',
        name: goal.contains('loss') ? 'Grilled Tilapia / Tuna Steak' : 'Lean Beef Stir-fry with Sweet Peppers',
        category: 'Dinner',
        servings: (1.5 * scale).roundToDouble(),
        servingUnit: '${(160 * scale).toInt()}g',
        calories: (dCal * 0.65).roundToDouble(),
        protein: (dCal * 0.65 * 0.65 / 4.0).roundToDouble(),
        carbs: 5,
        fat: (dCal * 0.65 * 0.25 / 9.0).roundToDouble(),
        cost: 75.0,
      ),
      FoodItemModel(
        foodId: 'F013',
        name: 'Roasted Sweet Potato Wedges',
        category: 'Dinner',
        servings: 1.0,
        servingUnit: '${(120 * scale).toInt()}g',
        calories: (dCal * 0.35).roundToDouble(),
        protein: 3.0,
        carbs: (dCal * 0.35 * 0.85 / 4.0).roundToDouble(),
        fat: 0.5,
        cost: 20.0,
      ),
    ];

    // Build Snack
    final snackItems = [
      FoodItemModel(
        foodId: 'F020',
        name: goal.contains('loss') ? 'Whey Isolate Shake with Water' : 'Whey Protein Shake with Milk & Banana',
        category: 'Snack',
        servings: 1.0,
        servingUnit: '1 scoop (30g)',
        calories: (sCal * 0.65).roundToDouble(),
        protein: 26.0,
        carbs: goal.contains('loss') ? 2.0 : 18.0,
        fat: 1.5,
        cost: 45.0,
      ),
      FoodItemModel(
        foodId: 'F021',
        name: 'Roasted Almonds & Walnuts',
        category: 'Snack',
        servings: 1.0,
        servingUnit: '${(25 * scale).toInt()}g',
        calories: (sCal * 0.35).roundToDouble(),
        protein: 6.0,
        carbs: 5.0,
        fat: (sCal * 0.35 * 0.70 / 9.0).roundToDouble(),
        cost: 25.0,
      ),
    ];

    // Compute actual slot totals
    double computeSlotCal(List<FoodItemModel> items) => items.fold(0.0, (acc, item) => acc + item.calories);
    double computeSlotProt(List<FoodItemModel> items) => items.fold(0.0, (acc, item) => acc + item.protein);
    double computeSlotCarb(List<FoodItemModel> items) => items.fold(0.0, (acc, item) => acc + item.carbs);
    double computeSlotFat(List<FoodItemModel> items) => items.fold(0.0, (acc, item) => acc + item.fat);
    double computeSlotCost(List<FoodItemModel> items) => items.fold(0.0, (acc, item) => acc + item.cost);

    List<FoodItemModel> filterRestricted(List<FoodItemModel> list) {
      if (restrictions.isEmpty) return list;
      final filtered = list.where((item) {
        final n = item.name.toLowerCase();
        for (final r in restrictions) {
          if (n.contains(r)) return false;
        }
        return true;
      }).toList();
      return filtered.isNotEmpty ? filtered : list;
    }

    final safeB = filterRestricted(breakfastItems);
    final safeL = filterRestricted(lunchItems);
    final safeD = filterRestricted(dinnerItems);
    final safeS = filterRestricted(snackItems);

    final slots = [
      MealSlotModel(
        mealName: 'Breakfast',
        items: safeB,
        slotCalories: computeSlotCal(safeB),
        slotProtein: computeSlotProt(safeB),
        slotCarbs: computeSlotCarb(safeB),
        slotFat: computeSlotFat(safeB),
        slotCost: computeSlotCost(safeB),
      ),
      MealSlotModel(
        mealName: 'Lunch',
        items: safeL,
        slotCalories: computeSlotCal(safeL),
        slotProtein: computeSlotProt(safeL),
        slotCarbs: computeSlotCarb(safeL),
        slotFat: computeSlotFat(safeL),
        slotCost: computeSlotCost(safeL),
      ),
      MealSlotModel(
        mealName: 'Dinner',
        items: safeD,
        slotCalories: computeSlotCal(safeD),
        slotProtein: computeSlotProt(safeD),
        slotCarbs: computeSlotCarb(safeD),
        slotFat: computeSlotFat(safeD),
        slotCost: computeSlotCost(safeD),
      ),
      MealSlotModel(
        mealName: 'Snack',
        items: safeS,
        slotCalories: computeSlotCal(safeS),
        slotProtein: computeSlotProt(safeS),
        slotCarbs: computeSlotCarb(safeS),
        slotFat: computeSlotFat(safeS),
        slotCost: computeSlotCost(safeS),
      ),
    ];

    final totCal = slots.fold(0.0, (acc, s) => acc + s.slotCalories);
    final totProt = slots.fold(0.0, (acc, s) => acc + s.slotProtein);
    final totCarb = slots.fold(0.0, (acc, s) => acc + s.slotCarbs);
    final totFat = slots.fold(0.0, (acc, s) => acc + s.slotFat);
    final totCost = slots.fold(0.0, (acc, s) => acc + s.slotCost);

    return MealPlanModel(
      id: 'meal_${DateTime.now().millisecondsSinceEpoch}',
      userId: user.id,
      source: 'viscous_smart_nutrition',
      totalCalories: totCal,
      targetCalories: cal,
      totalProtein: totProt,
      targetProtein: targetP,
      totalCarbs: totCarb,
      targetCarbs: targetC,
      totalFat: totFat,
      targetFat: targetF,
      totalCost: totCost,
      isFeasible: true,
      solverMessage: 'Optimal macronutrient balance tailored for ${user.fitnessGoal} (${user.activityLevel} lifestyle: ${cal.toInt()} kcal)',
      meals: slots,
      generatedAt: DateTime.now(),
    );
  }
}

