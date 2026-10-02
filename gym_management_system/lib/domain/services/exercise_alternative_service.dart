import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/facility_entity.dart';
import '../entities/workout_plan_entity.dart';

final exerciseAlternativeServiceProvider = Provider<ExerciseAlternativeService>((ref) {
  return ExerciseAlternativeService();
});

class AlternativeRecommendation {
  final String originalExerciseName;
  final String originalEquipment;
  final String alternativeName;
  final String alternativeEquipment;
  final String muscleGroup;
  final String sets;
  final String reps;
  final int restSec;
  final String instructions;
  final int matchPercentage;
  final String aiRationale;
  final bool isOccupied;
  final String? occupiedReason;

  const AlternativeRecommendation({
    required this.originalExerciseName,
    required this.originalEquipment,
    required this.alternativeName,
    required this.alternativeEquipment,
    required this.muscleGroup,
    required this.sets,
    required this.reps,
    required this.restSec,
    required this.instructions,
    required this.matchPercentage,
    required this.aiRationale,
    this.isOccupied = false,
    this.occupiedReason,
  });

  ExerciseEntity toExerciseEntity({String dayTag = ''}) {
    return ExerciseEntity(
      name: alternativeName,
      muscleGroup: muscleGroup,
      sets: sets,
      reps: reps,
      restSec: restSec,
      equipment: alternativeEquipment,
      instructions: 'AI Alternative ($matchPercentage% Match): $instructions (Rationale: $aiRationale)',
      isCompleted: false,
      dayTag: dayTag,
    );
  }
}

class ExerciseAlternativeService {
  /// Checks whether the equipment required for this exercise is currently occupied or under maintenance in the gym,
  /// or if the facility zone hosting this equipment is at 100% capacity.
  bool isEquipmentOccupied(
    ExerciseEntity exercise, {
    List<EquipmentEntity> equipment = const [],
    List<FacilityEntity> facilities = const [],
  }) {
    return getOccupancyNotice(exercise, equipment: equipment, facilities: facilities) != null;
  }

  /// Returns a descriptive message if the equipment or its hosting facility is occupied / in-use / at capacity.
  String? getOccupancyNotice(
    ExerciseEntity exercise, {
    List<EquipmentEntity> equipment = const [],
    List<FacilityEntity> facilities = const [],
  }) {
    final eqName = exercise.equipment.toLowerCase();
    final exName = exercise.name.toLowerCase();

    // Check specific equipment units
    for (final eq in equipment) {
      final unitName = eq.name.toLowerCase();
      final matchesName = eqName.contains(unitName) || unitName.contains(eqName) || exName.contains(unitName);
      if (matchesName) {
        if (eq.isOccupied) {
          return '${eq.name} is currently in-use / occupied by another member.';
        }
        if (eq.isUnderMaintenance || eq.isOutOfOrder) {
          return '${eq.name} is currently under maintenance / unavailable.';
        }

        // Also check if the zone where this equipment resides is fully occupied
        for (final fac in facilities) {
          if (fac.id == eq.facilityId && fac.isFullyOccupied) {
            return '${fac.name} is currently at full capacity (${fac.currentOccupancy}/${fac.capacity} members).';
          }
        }
      }
    }

    // Check if the exercise name indicates a general machine whose hosting zone is at full capacity
    for (final fac in facilities) {
      if (fac.isFullyOccupied) {
        final facName = fac.name.toLowerCase();
        if (facName.contains('free weights') && (eqName.contains('rack') || eqName.contains('bench') || eqName.contains('dumbbell'))) {
          return '${fac.name} is currently at full capacity (${fac.currentOccupancy}/${fac.capacity}).';
        }
        if (facName.contains('cardio') && (eqName.contains('treadmill') || eqName.contains('rower') || eqName.contains('cardio'))) {
          return '${fac.name} is currently at full capacity (${fac.currentOccupancy}/${fac.capacity}).';
        }
      }
    }

    return null;
  }

  /// Generates AI-driven biomechanically matched alternative exercises.
  List<AlternativeRecommendation> getAlternatives({
    required ExerciseEntity exercise,
    List<EquipmentEntity> equipment = const [],
    List<FacilityEntity> facilities = const [],
  }) {
    final notice = getOccupancyNotice(exercise, equipment: equipment, facilities: facilities);
    final isOcc = notice != null;

    final nameLower = exercise.name.toLowerCase();
    final equipLower = exercise.equipment.toLowerCase();

    // 1. Leg Press Machine / Hack Squat
    if (nameLower.contains('leg press') || equipLower.contains('leg press') || nameLower.contains('hack squat')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Bulgarian Split Squat',
          alternativeEquipment: 'Dumbbells & Flat Bench',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Quadriceps & Glutes',
          sets: exercise.sets,
          reps: '10-12 / leg',
          restSec: 75,
          instructions: 'Elevate rear foot on bench; descend vertically with chest tall to isolate single-leg quad extension without spinal compression.',
          matchPercentage: 96,
          aiRationale: 'Provides identical high-load quadriceps motor unit recruitment and deep knee flexion without needing the occupied Leg Press carriage.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Goblet Squat (Heels Elevated)',
          alternativeEquipment: 'Dumbbell & Weight Plate',
          muscleGroup: 'Quadriceps',
          sets: exercise.sets,
          reps: exercise.reps,
          restSec: 60,
          instructions: 'Hold a heavy dumbbell against chest; elevate heels on a 5kg plate to maximize anterior knee displacement and quad drive.',
          matchPercentage: 93,
          aiRationale: 'Elevating heels mirrors the footplate angle of the Leg Press, shifting load cleanly into the vastus medialis and lateralis.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Barbell Front Squat',
          alternativeEquipment: 'Barbell & Squat Rack',
          muscleGroup: 'Quadriceps & Upper Back',
          sets: exercise.sets,
          reps: '8-10',
          restSec: 90,
          instructions: 'Rest barbell on front anterior deltoids; maintain upright torso during deep squatting descent.',
          matchPercentage: 90,
          aiRationale: 'Anterior barbell placement forces high quadriceps mechanical tension identical to 45-degree leg press loading.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 2. Lat Pull Down Machine
    if (nameLower.contains('lat pull') || equipLower.contains('lat pull') || nameLower.contains('pulldown')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Pull-Ups / Band-Assisted Pull-Ups',
          alternativeEquipment: 'Pull-Up Bar',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Lats & Upper Back',
          sets: exercise.sets,
          reps: '8-10',
          restSec: 75,
          instructions: 'Grip pull-up bar slightly wider than shoulder-width. Drive elbows down into back pockets and squeeze lats at the top.',
          matchPercentage: 98,
          aiRationale: 'Biochemically identical vertical pulling path of motion that engages latissimus dorsi and teres major without cable dependencies.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Lat-Focused Single-Arm Dumbbell Row',
          alternativeEquipment: 'Dumbbell & Bench',
          muscleGroup: 'Lats & Rhomboids',
          sets: exercise.sets,
          reps: '10-12 / arm',
          restSec: 60,
          instructions: 'Hinge at hip, pull dumbbell towards your hip crest rather than ribcage, keeping elbow tucked to isolate lat insertion.',
          matchPercentage: 94,
          aiRationale: 'Low-arcing dumbbell row angle stimulates the lower lat fibers with superior unilateral focus.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Straight-Arm Pullover',
          alternativeEquipment: 'Dumbbell & Flat Bench',
          muscleGroup: 'Lats & Serratus',
          sets: exercise.sets,
          reps: '12',
          restSec: 60,
          instructions: 'Lie across bench supporting shoulders. Lower dumbbell overhead in a controlled arc, feeling deep stretch in lats before pulling back over chest.',
          matchPercentage: 89,
          aiRationale: 'Replicates the overhead elongation and shoulder adduction of a lat pulldown using only a single dumbbell.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 3. Peck Deck Fly Machine / Cable Crossover / Chest Fly
    if (nameLower.contains('pec deck') || nameLower.contains('peck deck') || nameLower.contains('chest fly') || equipLower.contains('pec deck') || equipLower.contains('cable crossover')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Flat Dumbbell Chest Flyes',
          alternativeEquipment: 'Dumbbells & Flat Bench',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Pectorals (Chest)',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 60,
          instructions: 'Lie on flat bench, slight bend in elbows. Open arms in a wide hugging arc until chest is stretched, then squeeze pectorals together at top.',
          matchPercentage: 96,
          aiRationale: 'Identical horizontal adduction movement profile providing peak stretch and contraction across sternal pectoral fibers.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Incline Dumbbell Flyes',
          alternativeEquipment: 'Dumbbells & Incline Bench',
          muscleGroup: 'Upper Pectorals',
          sets: exercise.sets,
          reps: '12',
          restSec: 60,
          instructions: 'Set bench to 30 degrees. Perform wide fly motion emphasizing the clavicular upper chest stretch.',
          matchPercentage: 93,
          aiRationale: 'Shifts tension slightly higher onto upper pectoral heads while maintaining horizontal fly mechanics.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Deficit Push-Ups on Dumbbells',
          alternativeEquipment: 'Dumbbells on Floor',
          muscleGroup: 'Chest & Core',
          sets: exercise.sets,
          reps: '12-15',
          restSec: 60,
          instructions: 'Grip dumbbells on floor to increase range of motion. Descend below hand level for maximum pectoral stretch, then press explosively.',
          matchPercentage: 90,
          aiRationale: 'Delivers full chest activation and deep passive stretch without requiring any machine or cable stations.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 4. Machine Curl / Preacher Curl Machine
    if (nameLower.contains('machine curl') || equipLower.contains('machine curl') || nameLower.contains('preacher')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Incline Dumbbell Bicep Curl',
          alternativeEquipment: 'Dumbbells & Incline Bench',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Biceps Brachii',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 45,
          instructions: 'Sit on bench angled at 45-60 degrees. Allow arms to hang freely behind torso to put long head of biceps under maximal passive stretch.',
          matchPercentage: 96,
          aiRationale: 'The incline angle isolates the biceps long head and prevents shoulder involvement just like an arm curl machine.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Concentration Curl',
          alternativeEquipment: 'Dumbbell & Bench',
          muscleGroup: 'Biceps Peak',
          sets: exercise.sets,
          reps: '12 / arm',
          restSec: 45,
          instructions: 'Brace tricep against inner thigh. Curl dumbbell strictly towards face without swinging upper torso.',
          matchPercentage: 94,
          aiRationale: 'Strict mechanical brace eliminates momentum and produces intense peak bicep contraction identical to preacher machines.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Standing Dumbbell Hammer Curl',
          alternativeEquipment: 'Dumbbells',
          muscleGroup: 'Brachialis & Forearms',
          sets: exercise.sets,
          reps: '12',
          restSec: 45,
          instructions: 'Palms facing each other in neutral grip. Curl dumbbells to shoulder height controlling eccentric descent.',
          matchPercentage: 91,
          aiRationale: 'Builds arm thickness through the brachialis and brachioradialis with zero machine setup required.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 5. Cable Tricep Pushdown / Tricep Machine
    if (nameLower.contains('tricep pushdown') || equipLower.contains('cable') && nameLower.contains('tricep')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Overhead Dumbbell Tricep Extension',
          alternativeEquipment: 'Dumbbell & Bench',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Triceps',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 45,
          instructions: 'Hold a dumbbell with both hands overhead. Lower behind head by flexing at elbows while keeping upper arms vertical, then lock out triceps.',
          matchPercentage: 96,
          aiRationale: 'Overhead positioning places the long head of the tricep under maximum stretch, inducing superior hypertrophy compared to pushdowns.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Skull Crushers (Lying Tricep Ext)',
          alternativeEquipment: 'Dumbbells & Flat Bench',
          muscleGroup: 'Triceps',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 60,
          instructions: 'Lie on flat bench holding dumbbells upright. Lower dumbbells toward temples bending only elbows, then extend back to vertical.',
          matchPercentage: 94,
          aiRationale: 'Direct elbow extension against gravity mirrors cable pushdown tension across medial and lateral tricep heads.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Diamond Close-Grip Push-Ups / Bench Dips',
          alternativeEquipment: 'Floor / Flat Bench',
          muscleGroup: 'Triceps & Chest',
          sets: exercise.sets,
          reps: '12-15',
          restSec: 45,
          instructions: 'Place index fingers and thumbs together under chest. Press up focusing solely on tricep lockout.',
          matchPercentage: 89,
          aiRationale: 'High-density bodyweight compound loading triceps with zero equipment dependencies.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 6. Calf Raises Machine
    if (nameLower.contains('calf') || equipLower.contains('calf')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Single-Leg Standing DB Calf Raise on Step',
          alternativeEquipment: 'Dumbbell & Step / Plate',
          muscleGroup: 'Calves (Gastrocnemius & Soleus)',
          sets: exercise.sets,
          reps: '15 / leg',
          restSec: 45,
          instructions: 'Place ball of one foot on a step with heel hanging off. Hold dumbbell in same-side hand. Drop heel for full stretch, then rise onto toes.',
          matchPercentage: 98,
          aiRationale: 'Single-leg loading duplicates machine resistance and fixes side-to-side ankle mobility and calf imbalances.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Seated Dumbbell Calf Raise (Knee Loaded)',
          alternativeEquipment: 'Dumbbells & Flat Bench',
          muscleGroup: 'Soleus',
          sets: exercise.sets,
          reps: '15-20',
          restSec: 45,
          instructions: 'Sit on bench, place heavy dumbbells atop knees with balls of feet elevated on a plate. Raise heels with controlled 2s pause at top.',
          matchPercentage: 94,
          aiRationale: 'Bent-knee angle disengages gastrocnemius to isolate the deep soleus muscle just like a seated calf raise machine.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 7. Seated Cable Row / Row Machine
    if (nameLower.contains('row machine') || nameLower.contains('seated cable row') || equipLower.contains('row machine')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Chest-Supported Incline Dumbbell Row',
          alternativeEquipment: 'Dumbbells & Incline Bench',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Upper Back & Rhomboids',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 60,
          instructions: 'Lie chest-down on a 30-degree incline bench. Row dumbbells towards hips retracting scapulae with no lower-back momentum.',
          matchPercentage: 96,
          aiRationale: 'Chest support replicates the rigid torso stabilization of a seated row machine without putting axial load on the lumbar spine.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Single-Arm Dumbbell Row',
          alternativeEquipment: 'Dumbbell & Bench',
          muscleGroup: 'Lats & Rhomboids',
          sets: exercise.sets,
          reps: '10-12 / arm',
          restSec: 60,
          instructions: 'Support torso on bench with one hand and knee. Pull dumbbell back to hip crest with tucked elbow.',
          matchPercentage: 94,
          aiRationale: 'Unilateral horizontal rowing provides maximum lat stretch and powerful contraction.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Bent-Over Barbell Row',
          alternativeEquipment: 'Barbell & Weight Plates',
          muscleGroup: 'Upper Back & Lats',
          sets: exercise.sets,
          reps: '8-10',
          restSec: 75,
          instructions: 'Hinge at hips at 45 degrees. Pull bar to upper abdomen driving elbows backward.',
          matchPercentage: 91,
          aiRationale: 'Heavy compound free weight horizontal pull providing massive upper back density.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 8. Leg Extension Machine
    if (nameLower.contains('leg extension') || equipLower.contains('leg extension')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Bodyweight / DB Sissy Squats (Heels Elevated)',
          alternativeEquipment: 'Bodyweight / Dumbbell & Step',
          muscleGroup: 'Quadriceps (Rectus Femoris)',
          sets: exercise.sets,
          reps: '12-15',
          restSec: 60,
          instructions: 'Hold onto a rack or wall for balance, elevate heels. Push knees forward while leaning torso back in a straight line to load quads under full stretch.',
          matchPercentage: 96,
          aiRationale: 'Extreme knee flexion and hip extension directly isolates the rectus femoris muscle exactly like a leg extension.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Reverse Nordic Curls',
          alternativeEquipment: 'Exercise Mat',
          muscleGroup: 'Quadriceps & Hip Flexors',
          sets: exercise.sets,
          reps: '8-10',
          restSec: 60,
          instructions: 'Kneel on mat with hips extended. Lean torso backwards using quads to brake descent, then contract quads to pull back up.',
          matchPercentage: 94,
          aiRationale: 'Bodyweight eccentric overload targeting the entire quadriceps tendon mechanism without any machines.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 9. Leg Curl Machine (Lying or Seated)
    if (nameLower.contains('leg curl') || equipLower.contains('leg curl')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Romanian Deadlift (RDL)',
          alternativeEquipment: 'Dumbbells',
          muscleGroup: 'Hamstrings & Glutes',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 75,
          instructions: 'Hold dumbbells in front of thighs. Soft knee bend, push hips backwards while maintaining flat spine until deep hamstring stretch is reached.',
          matchPercentage: 96,
          aiRationale: 'Eccentric hip hinge targets the proximal hamstring tendon with proven superior muscle-building stimulus.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Prone Hamstring Curl',
          alternativeEquipment: 'Dumbbell & Flat Bench',
          muscleGroup: 'Hamstrings (Knee Flexion)',
          sets: exercise.sets,
          reps: '12',
          restSec: 60,
          instructions: 'Lie prone on flat bench clamping a dumbbell securely between feet. Flex knees to curl dumbbell towards glutes, then lower slowly.',
          matchPercentage: 93,
          aiRationale: 'True knee flexion hamstring isolation using only a standard dumbbell and flat bench.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Nordic Hamstring Curls (Partner/Band Assisted)',
          alternativeEquipment: 'Mat & Anchor Point',
          muscleGroup: 'Hamstrings',
          sets: exercise.sets,
          reps: '6-8',
          restSec: 90,
          instructions: 'Anchor ankles under barbell or heavy pads. Lower torso forward under strict hamstring control.',
          matchPercentage: 91,
          aiRationale: 'Gold-standard athletic hamstring strength builder proven to reduce hamstring strains.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 10. Shoulder Press Machine
    if (nameLower.contains('shoulder press') || equipLower.contains('shoulder press')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Seated Dumbbell Overhead Press',
          alternativeEquipment: 'Dumbbells & Adjustable Bench',
          muscleGroup: exercise.muscleGroup.isNotEmpty ? exercise.muscleGroup : 'Deltoids & Shoulders',
          sets: exercise.sets,
          reps: '8-10',
          restSec: 75,
          instructions: 'Sit with back supported. Press dumbbells overhead with elbows slightly in front of shoulders in the natural scapular plane.',
          matchPercentage: 97,
          aiRationale: 'Free weight vertical press recruits anterior and lateral deltoids while promoting shoulder joint health and stabilization.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Arnold Dumbbell Press',
          alternativeEquipment: 'Dumbbells & Bench',
          muscleGroup: 'Deltoids & Upper Chest',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 60,
          instructions: 'Start with dumbbells at chin height, palms facing in. Rotate wrists outward as you press overhead.',
          matchPercentage: 94,
          aiRationale: 'Wrist rotation stimulates all three deltoid heads through an extended range of motion.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Pike Push-Ups (Elevated Feet)',
          alternativeEquipment: 'Bench & Floor',
          muscleGroup: 'Deltoids & Triceps',
          sets: exercise.sets,
          reps: '10-12',
          restSec: 60,
          instructions: 'Elevate feet on bench, hips bent at 90 degrees directly over hands. Lower crown of head toward floor and press back up.',
          matchPercentage: 88,
          aiRationale: 'Bodyweight overhead pressing alternative requiring zero equipment.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 11. Commercial Treadmill / Cardio Stations
    if (nameLower.contains('treadmill') || equipLower.contains('treadmill') || equipLower.contains('cardio')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Assault AirBike Sprints / Stationary Spin Bike',
          alternativeEquipment: 'AirBike or Spin Bike',
          muscleGroup: 'Cardiovascular & Lower Body',
          sets: exercise.sets,
          reps: exercise.reps.contains('min') ? exercise.reps : '15-20 mins',
          restSec: 45,
          instructions: 'Maintain vigorous aerobic cadence. Incorporate 30s high-intensity bursts every 2 minutes.',
          matchPercentage: 96,
          aiRationale: 'Provides high caloric burn and VO2 max improvement with zero joint impact when treadmills are fully occupied.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Concept2 Rower Intervals',
          alternativeEquipment: 'Rowing Machine',
          muscleGroup: 'Full Body Cardiovascular',
          sets: '5 rounds',
          reps: '250m intervals',
          restSec: 60,
          instructions: 'Drive through heels, open hips, pull handle to lower ribs. Rest 60s between 250m sprints.',
          matchPercentage: 94,
          aiRationale: 'Recruits 85% of total body skeletal muscle mass, burning more calories per minute than steady-state running.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Speed Jump Rope Intervals & High Knees',
          alternativeEquipment: 'Jump Rope & Mat',
          muscleGroup: 'Cardiovascular & Calves',
          sets: '6 rounds',
          reps: '45s on / 15s off',
          restSec: 30,
          instructions: 'Stay light on balls of feet. Alternate between speed skips, double-unders, and running high knees.',
          matchPercentage: 90,
          aiRationale: 'Immediate high-intensity cardio workout that can be done anywhere in the gym turf with no machine wait time.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // 12. General Muscle Group Fallback
    final mg = exercise.muscleGroup.toLowerCase();

    if (mg.contains('chest') || mg.contains('pectoral')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Flat Dumbbell Chest Press',
          alternativeEquipment: 'Dumbbells & Flat Bench',
          muscleGroup: exercise.muscleGroup,
          sets: exercise.sets,
          reps: exercise.reps,
          restSec: exercise.restSec,
          instructions: 'Lower dumbbells with elbows at 45-degree angle. Press up and converge dumbbells at peak contraction.',
          matchPercentage: 95,
          aiRationale: 'Primary compound chest builder providing full pectoral stretch and bilateral balance.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Incline Dumbbell Press',
          alternativeEquipment: 'Dumbbells & Incline Bench',
          muscleGroup: 'Upper Chest',
          sets: exercise.sets,
          reps: '10-12',
          restSec: exercise.restSec,
          instructions: 'Set bench to 30 degrees. Press dumbbells overhead targeting the clavicular pectoral fibers.',
          matchPercentage: 92,
          aiRationale: 'Emphasizes upper chest development using dumbbells when chest machines are occupied.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    } else if (mg.contains('back') || mg.contains('lat')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Single-Arm Dumbbell Row',
          alternativeEquipment: 'Dumbbell & Flat Bench',
          muscleGroup: exercise.muscleGroup,
          sets: exercise.sets,
          reps: '10-12 / arm',
          restSec: 60,
          instructions: 'Support knee on bench, pull dumbbell to hip crest keeping elbow tucked to isolate lat.',
          matchPercentage: 95,
          aiRationale: 'Unilateral lat development without equipment congestion.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Bent-Over Barbell Row',
          alternativeEquipment: 'Barbell',
          muscleGroup: exercise.muscleGroup,
          sets: exercise.sets,
          reps: exercise.reps,
          restSec: exercise.restSec,
          instructions: 'Hinge forward at 45 degrees. Pull bar to naval squeezing shoulder blades.',
          matchPercentage: 91,
          aiRationale: 'Total back mass builder utilizing standard barbell plates.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    } else if (mg.contains('quad') || mg.contains('leg')) {
      return [
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Bulgarian Split Squats',
          alternativeEquipment: 'Dumbbells & Flat Bench',
          muscleGroup: exercise.muscleGroup,
          sets: exercise.sets,
          reps: '10-12 / leg',
          restSec: 75,
          instructions: 'Elevate rear foot on bench; descend vertically with chest tall to isolate single-leg quad extension.',
          matchPercentage: 95,
          aiRationale: 'Peak single-leg quad overload without machine queue times.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
        AlternativeRecommendation(
          originalExerciseName: exercise.name,
          originalEquipment: exercise.equipment,
          alternativeName: 'Dumbbell Goblet Squats',
          alternativeEquipment: 'Dumbbell',
          muscleGroup: exercise.muscleGroup,
          sets: exercise.sets,
          reps: exercise.reps,
          restSec: exercise.restSec,
          instructions: 'Hold dumbbell at chest. Squat deeply between knees keeping torso vertical.',
          matchPercentage: 92,
          aiRationale: 'Anteriorly loaded knee flexion that builds quad mass safely.',
          isOccupied: isOcc,
          occupiedReason: notice,
        ),
      ];
    }

    // Default universal fallback
    return [
      AlternativeRecommendation(
        originalExerciseName: exercise.name,
        originalEquipment: exercise.equipment,
        alternativeName: 'Dumbbell Alternative (${exercise.name.replaceAll('Machine', '').trim()})',
        alternativeEquipment: 'Dumbbells & Bench',
        muscleGroup: exercise.muscleGroup,
        sets: exercise.sets,
        reps: exercise.reps,
        restSec: exercise.restSec,
        instructions: 'Perform equivalent movement path with dumbbells to maintain targeted muscle tension without machine dependencies.',
        matchPercentage: 92,
        aiRationale: 'Dumbbells allow full range of motion and personalized biomechanical joint alignment.',
        isOccupied: isOcc,
        occupiedReason: notice,
      ),
    ];
  }
}
