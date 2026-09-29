import joblib
import pandas as pd

model = joblib.load('app/models/workout_classifier.joblib')
cases = [
    {'age': 25, 'gender': 'Male', 'bmi': 28.5, 'fitness_goal': 'Weight Loss', 'activity_level': 'Sedentary', 'experience_level': 'Beginner'},
    {'age': 25, 'gender': 'Male', 'bmi': 24.0, 'fitness_goal': 'Muscle Gain', 'activity_level': 'Moderately Active', 'experience_level': 'Intermediate'},
    {'age': 25, 'gender': 'Male', 'bmi': 23.0, 'fitness_goal': 'Muscle Gain', 'activity_level': 'Very Active', 'experience_level': 'Advanced'},
    {'age': 25, 'gender': 'Female', 'bmi': 21.0, 'fitness_goal': 'Improve Endurance', 'activity_level': 'Moderately Active', 'experience_level': 'Intermediate'},
    {'age': 30, 'gender': 'Female', 'bmi': 25.0, 'fitness_goal': 'General Fitness', 'activity_level': 'Lightly Active', 'experience_level': 'Beginner'},
]
for c in cases:
    df = pd.DataFrame([c])
    pred = model.predict(df)[0]
    proba = max(model.predict_proba(df)[0])
    goal = c['fitness_goal']
    exp = c['experience_level']
    act = c['activity_level']
    print(f"{goal:18} | {exp:12} | {act:17} -> {pred} ({proba*100:.1f}%)")
