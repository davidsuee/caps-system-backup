import os
import joblib
import pandas as pd
import numpy as np
from typing import List, Dict, Any
from app.schemas.workout_schema import WorkoutRecommendationRequest, WorkoutRecommendationResponse, ExerciseItem

MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'models', 'workout_classifier.joblib')

EXERCISE_CATALOG = {
    'Push': [
        {'name': 'Barbell Bench Press', 'muscle_group': 'Chest', 'sets': '4', 'reps': '8-10', 'rest_sec': 90, 'equipment': 'Barbell & Bench', 'injury_risk': 'shoulder'},
        {'name': 'Incline Dumbbell Press', 'muscle_group': 'Upper Chest', 'sets': '3', 'reps': '10-12', 'rest_sec': 75, 'equipment': 'Dumbbells', 'injury_risk': 'shoulder'},
        {'name': 'Overhead Military Press', 'muscle_group': 'Shoulders', 'sets': '3', 'reps': '8-10', 'rest_sec': 90, 'equipment': 'Barbell', 'injury_risk': 'shoulder'},
        {'name': 'Dumbbell Lateral Raises', 'muscle_group': 'Lateral Delts', 'sets': '4', 'reps': '12-15', 'rest_sec': 60, 'equipment': 'Dumbbells', 'injury_risk': None},
        {'name': 'Tricep Cable Pushdowns', 'muscle_group': 'Triceps', 'sets': '3', 'reps': '12-15', 'rest_sec': 60, 'equipment': 'Cable Machine', 'injury_risk': None},
        {'name': 'Push-ups', 'muscle_group': 'Chest & Core', 'sets': '3', 'reps': '15-20', 'rest_sec': 60, 'equipment': 'Bodyweight', 'injury_risk': None},
    ],
    'Pull': [
        {'name': 'Barbell Deadlift', 'muscle_group': 'Back & Hamstrings', 'sets': '4', 'reps': '6-8', 'rest_sec': 120, 'equipment': 'Barbell', 'injury_risk': 'lower_back'},
        {'name': 'Lat Pulldown', 'muscle_group': 'Upper Back', 'sets': '4', 'reps': '10-12', 'rest_sec': 75, 'equipment': 'Cable Machine', 'injury_risk': None},
        {'name': 'Seated Cable Row', 'muscle_group': 'Mid Back', 'sets': '3', 'reps': '10-12', 'rest_sec': 75, 'equipment': 'Cable Machine', 'injury_risk': 'lower_back'},
        {'name': 'Barbell Bicep Curl', 'muscle_group': 'Biceps', 'sets': '3', 'reps': '10-12', 'rest_sec': 60, 'equipment': 'Barbell', 'injury_risk': None},
        {'name': 'Hammer Curls', 'muscle_group': 'Brachialis & Forearms', 'sets': '3', 'reps': '12-15', 'rest_sec': 60, 'equipment': 'Dumbbells', 'injury_risk': None},
        {'name': 'Face Pulls', 'muscle_group': 'Rear Delts & Rotator Cuff', 'sets': '3', 'reps': '15', 'rest_sec': 60, 'equipment': 'Cable Machine', 'injury_risk': None},
    ],
    'Legs': [
        {'name': 'Barbell Back Squat', 'muscle_group': 'Quadriceps & Glutes', 'sets': '4', 'reps': '8-10', 'rest_sec': 120, 'equipment': 'Barbell & Squat Rack', 'injury_risk': 'knee'},
        {'name': 'Romanian Deadlift', 'muscle_group': 'Hamstrings & Glutes', 'sets': '3', 'reps': '10-12', 'rest_sec': 90, 'equipment': 'Barbell / Dumbbells', 'injury_risk': 'lower_back'},
        {'name': 'Leg Press', 'muscle_group': 'Quadriceps', 'sets': '3', 'reps': '12-15', 'rest_sec': 90, 'equipment': 'Leg Press Machine', 'injury_risk': 'knee'},
        {'name': 'Standing Calf Raises', 'muscle_group': 'Calves', 'sets': '4', 'reps': '15-20', 'rest_sec': 45, 'equipment': 'Calf Machine / Step', 'injury_risk': None},
        {'name': 'Plank Hold', 'muscle_group': 'Core / Abs', 'sets': '3', 'reps': '45-60 sec', 'rest_sec': 45, 'equipment': 'Mat', 'injury_risk': None},
    ],
    'Upper': [
        {'name': 'Barbell Bench Press', 'muscle_group': 'Chest', 'sets': '4', 'reps': '8-10', 'rest_sec': 90, 'equipment': 'Barbell & Bench', 'injury_risk': 'shoulder'},
        {'name': 'Chest-Supported T-Bar Row', 'muscle_group': 'Upper Back', 'sets': '4', 'reps': '10-12', 'rest_sec': 75, 'equipment': 'T-Bar Machine', 'injury_risk': 'lower_back'},
        {'name': 'Overhead DB Shoulder Press', 'muscle_group': 'Shoulders', 'sets': '3', 'reps': '10-12', 'rest_sec': 60, 'equipment': 'Dumbbells', 'injury_risk': 'shoulder'},
        {'name': 'Lat Pulldown (Neutral Grip)', 'muscle_group': 'Back & Lats', 'sets': '3', 'reps': '12', 'rest_sec': 60, 'equipment': 'Cable Machine', 'injury_risk': None},
        {'name': 'Cable Tricep Pushdown & Bicep Curl', 'muscle_group': 'Arms', 'sets': '3', 'reps': '12-15', 'rest_sec': 45, 'equipment': 'Cable Station', 'injury_risk': None},
    ],
    'Conditioning': [
        {'name': 'Goblet Squats', 'muscle_group': 'Legs & Core', 'sets': '3', 'reps': '15', 'rest_sec': 45, 'equipment': 'Dumbbell / Kettlebell', 'injury_risk': 'knee'},
        {'name': 'Push-Up to Renegade Row', 'muscle_group': 'Chest & Core', 'sets': '3', 'reps': '12', 'rest_sec': 45, 'equipment': 'Dumbbells', 'injury_risk': 'shoulder'},
        {'name': 'Seated Cable Row', 'muscle_group': 'Back', 'sets': '3', 'reps': '12-15', 'rest_sec': 45, 'equipment': 'Cable Machine', 'injury_risk': None},
        {'name': 'Bodyweight Glute Bridge', 'muscle_group': 'Glutes & Core', 'sets': '3', 'reps': '15', 'rest_sec': 45, 'equipment:': 'Mat', 'injury_risk': None},
        {'name': 'Incline Treadmill Brisk Walk', 'muscle_group': 'Cardiovascular', 'sets': '1', 'reps': '20 mins', 'rest_sec': 0, 'equipment': 'Treadmill', 'injury_risk': None},
        {'name': 'High Plank Hold', 'muscle_group': 'Core Stability', 'sets': '3', 'reps': '45 sec', 'rest_sec': 30, 'equipment': 'Mat', 'injury_risk': None},
    ],
    'Full-Body': [
        {'name': 'Leg Press Machine', 'muscle_group': 'Quadriceps', 'sets': '3', 'reps': '12', 'rest_sec': 75, 'equipment': 'Leg Press', 'injury_risk': 'knee'},
        {'name': 'Dumbbell Flat Chest Press', 'muscle_group': 'Chest', 'sets': '3', 'reps': '10-12', 'rest_sec': 60, 'equipment': 'Dumbbells', 'injury_risk': 'shoulder'},
        {'name': 'Lat Pulldown', 'muscle_group': 'Back', 'sets': '3', 'reps': '12', 'rest_sec': 60, 'equipment': 'Cable Machine', 'injury_risk': None},
        {'name': 'Seated Dumbbell Shoulder Press', 'muscle_group': 'Shoulders', 'sets': '3', 'reps': '10-12', 'rest_sec': 60, 'equipment': 'Dumbbells', 'injury_risk': 'shoulder'},
        {'name': 'Romanian Dumbbell Deadlifts', 'muscle_group': 'Hamstrings & Glutes', 'sets': '3', 'reps': '12', 'rest_sec': 60, 'equipment': 'Dumbbells', 'injury_risk': 'lower_back'},
        {'name': 'Standard Elbow Plank', 'muscle_group': 'Core', 'sets': '3', 'reps': '45 sec', 'rest_sec': 45, 'equipment': 'Mat', 'injury_risk': None},
    ],
    'Cardio-HIIT': [
        {'name': 'High-Intensity Interval Treadmill Sprints', 'muscle_group': 'Full Body & Cardio', 'sets': '8 rounds', 'reps': '30s sprint / 60s walk', 'rest_sec': 60, 'equipment': 'Treadmill', 'injury_risk': 'knee'},
        {'name': 'Kettlebell Swings', 'muscle_group': 'Posterior Chain & Heart Rate', 'sets': '4', 'reps': '20', 'rest_sec': 45, 'equipment': 'Kettlebell', 'injury_risk': 'lower_back'},
        {'name': 'Burpees', 'muscle_group': 'Full Body Conditioning', 'sets': '4', 'reps': '12-15', 'rest_sec': 60, 'equipment': 'Bodyweight', 'injury_risk': 'shoulder'},
        {'name': 'Jump Rope', 'muscle_group': 'Calves & Endurance', 'sets': '3', 'reps': '3 mins', 'rest_sec': 60, 'equipment': 'Jump Rope', 'injury_risk': 'knee'},
        {'name': 'Battle Ropes', 'muscle_group': 'Shoulders, Arms & Core', 'sets': '4', 'reps': '30 sec', 'rest_sec': 45, 'equipment': 'Battle Ropes', 'injury_risk': None},
    ]
}

class MLWorkoutService:
    def __init__(self):
        self.model = None
        self._load_model()

    def _load_model(self):
        if os.path.exists(MODEL_PATH):
            try:
                self.model = joblib.load(MODEL_PATH)
                print(f"[ML Service] Loaded model successfully from {MODEL_PATH}")
            except Exception as e:
                print(f"[ML Service] Error loading model: {e}. Fallback logic enabled.")
                self.model = None
        else:
            print("[ML Service] Trained model file not found yet. Using rule-based fallback.")

    def recommend(self, req: WorkoutRecommendationRequest) -> WorkoutRecommendationResponse:
        bmi = round(req.weight_kg / ((req.height_cm / 100) ** 2), 1)
        
        split = "Full-Body Foundation"
        confidence = 0.88
        source = "rule_based_fallback"

        if self.model is not None:
            try:
                input_df = pd.DataFrame([{
                    'age': req.age,
                    'gender': req.gender,
                    'bmi': bmi,
                    'fitness_goal': req.fitness_goal,
                    'activity_level': req.activity_level,
                    'experience_level': req.experience_level
                }])
                
                predicted = self.model.predict(input_df)[0]
                proba = np.max(self.model.predict_proba(input_df)[0])
                split = str(predicted)
                confidence = float(proba)
                source = "ml_model_v1"
            except Exception as e:
                print(f"[ML Service] Inference error: {e}. Reverting to expert rules.")

        if source == "rule_based_fallback":
            if req.experience_level == 'Beginner':
                split = 'Full-Body Foundation' if req.fitness_goal != 'Weight Loss' else 'Full-Body Conditioning'
            elif req.fitness_goal == 'Muscle Gain':
                split = 'Push-Pull-Legs' if req.experience_level != 'Advanced' else 'Push-Pull-Legs Advanced'
            elif req.fitness_goal == 'Improve Endurance':
                split = 'Cardio-HIIT-Endurance'
            elif req.fitness_goal == 'Weight Loss':
                split = 'Upper-Lower Hypertrophy'
            else:
                split = 'Upper-Lower Balanced'

        # Determine weight bracket and phase
        wt = req.weight_kg
        goal = req.fitness_goal.lower()
        if 'muscle' in goal or 'gain' in goal:
            if wt < 70:
                phase_title = f"{split} (Phase 1: Hypertrophy Base • {int(wt)}kg)"
                phase_summary = f"Volume accumulation phase for {int(wt)}kg bodyweight. Focus on compound mechanical tension (8-12 reps) and baseline neuromuscular adaptation."
            elif wt < 77:
                phase_title = f"{split} (Phase 2: Progressive Overload • {int(wt)}kg)"
                phase_summary = f"Progressive overload phase for {int(wt)}kg bodyweight. Increasing load intensity (8-10 reps) to drive muscular hypertrophy."
            elif wt < 83:
                phase_title = f"{split} (Phase 3: Strength Overload • {int(wt)}kg)"
                phase_summary = f"Heavy strength overload phase for {int(wt)}kg bodyweight. High-density compound working sets (6-8 reps) with 90-120s rest."
            else:
                phase_title = f"{split} (Phase 4: Peak Power & Muscular Density • {int(wt)}kg)"
                phase_summary = f"Peak power & muscular density phase for {int(wt)}kg bodyweight. Heavy periodization (4-6 reps) plus targeted accessory volume."
        elif 'loss' in goal:
            if wt >= 80:
                phase_title = f"Metabolic Fat-Burn & Caloric Shred ({int(wt)}kg)"
                phase_summary = f"High-caloric expenditure metabolic circuit designed for {int(wt)}kg (BMI: {bmi}). Short rest intervals (30-45s) maximize fat oxidation."
            else:
                phase_title = f"Upper-Lower Lean Definition ({int(wt)}kg)"
                phase_summary = f"Antagonistic superset conditioning for {int(wt)}kg to maintain lean muscle mass while operating in a caloric deficit."
        elif 'endurance' in goal:
            phase_title = f"Cardio-HIIT & VO2 Max Engine ({int(wt)}kg)"
            phase_summary = f"Aerobic interval conditioning for {int(wt)}kg bodyweight. Focuses on lactate threshold and cardiac output."
        else:
            phase_title = f"Functional Strength & Mobility ({int(wt)}kg)"
            phase_summary = f"Balanced athletic foundation for {int(wt)}kg bodyweight enhancing postural stability and multi-joint strength."

        exercises = self._filter_exercises(split, req.injury_flags, req.available_equipment, req.experience_level, wt, req.fitness_goal)

        return WorkoutRecommendationResponse(
            status="success",
            recommended_split=phase_title,
            confidence_score=round(confidence, 3),
            source=source,
            summary=f"Tailored for {req.fitness_goal} ({req.experience_level} • {req.activity_level}, {int(wt)} kg, BMI: {bmi}). {phase_summary}",
            routine=exercises
        )

    def _filter_exercises(self, split: str, injuries: List[str], equipment: List[str], experience_level: str = 'Beginner', weight_kg: float = 70.0, fitness_goal: str = 'General Fitness') -> List[ExerciseItem]:
        lower_split = split.lower()
        goal = fitness_goal.lower()

        if 'loss' in goal:
            pool = [{**e, 'day_tag': 'Day 1: Full Body'} for e in EXERCISE_CATALOG['Conditioning']]
        elif 'endurance' in goal or 'cardio' in lower_split:
            pool = [{**e, 'day_tag': 'Day 1: Cardio & HIIT'} for e in EXERCISE_CATALOG['Cardio-HIIT']]
        elif 'muscle' in goal:
            pool = (
                [{**e, 'day_tag': 'Day 1: Push'} for e in EXERCISE_CATALOG['Push']] +
                [{**e, 'day_tag': 'Day 2: Pull'} for e in EXERCISE_CATALOG['Pull']] +
                [{**e, 'day_tag': 'Day 3: Legs & Core'} for e in EXERCISE_CATALOG['Legs']]
            )
        elif 'upper' in lower_split:
            pool = (
                [{**e, 'day_tag': 'Day 1: Upper'} for e in EXERCISE_CATALOG['Upper']] +
                [{**e, 'day_tag': 'Day 2: Lower'} for e in EXERCISE_CATALOG['Legs']]
            )
        else:
            pool = [{**e, 'day_tag': 'Day 1: Full Body'} for e in EXERCISE_CATALOG['Full-Body']]

        clean_injuries = [inj.lower().strip() for inj in injuries]
        res: List[ExerciseItem] = []

        is_beginner = 'beginner' in experience_level.lower()
        is_advanced = 'advanced' in experience_level.lower() or weight_kg >= 83

        for ex in pool:
            # Check injury risk
            risk = ex.get('injury_risk')
            if risk and any(risk in inj for inj in clean_injuries):
                continue

            name = ex['name']
            sets = ex['sets']
            reps = ex['reps']
            rest = ex['rest_sec']

            # Dynamic rep/set adaptation based on weight & goal
            if 'muscle' in goal:
                if weight_kg < 70:
                    sets = '4'
                    reps = '10-12'
                    rest = 75
                    target_ratio = 0.75
                elif weight_kg < 77:
                    sets = '4'
                    reps = '8-10'
                    rest = 90
                    target_ratio = 0.85
                elif weight_kg < 83:
                    sets = '4-5'
                    reps = '6-8'
                    rest = 105
                    target_ratio = 0.95
                else:
                    sets = '4-5'
                    reps = '5-6'
                    rest = 120
                    target_ratio = 1.05

                target_load = round(weight_kg * target_ratio, 1)
                instructions = f"Prescribed Target Load: ~{target_load:.0f} kg ({target_ratio:.2f}x BW). Progressive overload focus with {rest}s rest."
            elif 'loss' in goal:
                sets = '3-4'
                reps = '15-20'
                rest = 45
                target_load = max(8.0, round(weight_kg * 0.20, 1))
                instructions = f"Paced Metabolic Tempo: Use {target_load:.0f}kg DBs. Maintain high heart rate and explosive cadence."
            elif 'endurance' in goal:
                sets = '4-5'
                reps = '45-60s on'
                rest = 45
                instructions = "High-intensity aerobic stamina. Focus on rhythm and maximum output."
            else:
                sets = '3'
                reps = '10-12'
                rest = 60
                target_load = round(weight_kg * 0.60, 1)
                instructions = f"Form & Stability Focus: Target working weight ~{target_load:.0f} kg. Controlled tempo."

            res.append(ExerciseItem(
                name=name,
                muscle_group=ex['muscle_group'],
                sets=sets,
                reps=reps,
                rest_sec=rest,
                equipment=ex.get('equipment', 'Gym Equipment'),
                instructions=instructions,
                day_tag=ex.get('day_tag', '')
            ))


        if not res:
            res.append(ExerciseItem(
                name='Low-impact Walking & Mobility Drills',
                muscle_group='Full Body Recovery',
                sets='3',
                reps='15 mins',
                rest_sec=60,
                equipment='Bodyweight',
                instructions='Low impact movement safe for current limitations.'
            ))

        return res

ml_service = MLWorkoutService()

