"""
FITCORE ML Model Comprehensive Evaluation Script
Generates realistic metrics for capstone defense documentation.
Includes: cross-validation, confusion matrix data, feature importance, classification report.
"""
import os
import json
import numpy as np
import pandas as pd
from sklearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.metrics import (
    classification_report, accuracy_score, precision_recall_fscore_support,
    confusion_matrix
)

def generate_realistic_training_data(n_samples=1500, noise_rate=0.08):
    """Generate synthetic data WITH noise to simulate real-world conditions."""
    np.random.seed(42)
    goals = ['Weight Loss', 'Muscle Gain', 'Improve Endurance', 'General Fitness']
    genders = ['Male', 'Female', 'Other']
    activity_levels = ['Sedentary', 'Lightly Active', 'Moderately Active', 'Very Active']
    experience_levels = ['Beginner', 'Intermediate', 'Advanced']

    data = []
    for i in range(n_samples):
        age = np.random.randint(16, 68)
        gender = np.random.choice(genders, p=[0.48, 0.48, 0.04])
        goal = np.random.choice(goals)
        act = np.random.choice(activity_levels)
        exp = np.random.choice(experience_levels)

        # BMI generation with correlation to goal
        if goal == 'Weight Loss':
            bmi = np.random.normal(29.5, 4.0)
        elif goal == 'Muscle Gain':
            bmi = np.random.normal(23.5, 2.5)
        elif goal == 'Improve Endurance':
            bmi = np.random.normal(22.0, 2.0)
        else:
            bmi = np.random.normal(24.5, 3.0)
        bmi = float(np.clip(bmi, 16.5, 45.0))

        # Ground truth mapping based on ACSM guidelines
        if exp == 'Beginner':
            if goal == 'Weight Loss' or act == 'Sedentary':
                split = 'Full-Body Conditioning'
            else:
                split = 'Full-Body Foundation'
        elif exp == 'Intermediate':
            if goal == 'Muscle Gain':
                split = 'Push-Pull-Legs'
            elif goal == 'Weight Loss':
                split = 'Upper-Lower Hypertrophy'
            elif goal == 'Improve Endurance':
                split = 'Cardio-HIIT-Endurance'
            else:
                split = 'Upper-Lower Balanced'
        else:  # Advanced
            if goal == 'Muscle Gain':
                split = 'Push-Pull-Legs Advanced'
            elif goal == 'Improve Endurance':
                split = 'Cardio-HIIT-Endurance'
            else:
                split = 'Push-Pull-Legs'

        # Inject label noise to simulate real-world ambiguity
        all_splits = [
            'Full-Body Conditioning', 'Full-Body Foundation', 'Push-Pull-Legs',
            'Push-Pull-Legs Advanced', 'Upper-Lower Hypertrophy',
            'Upper-Lower Balanced', 'Cardio-HIIT-Endurance'
        ]
        if np.random.random() < noise_rate:
            split = np.random.choice(all_splits)

        data.append({
            'age': age, 'gender': gender, 'bmi': round(bmi, 1),
            'fitness_goal': goal, 'activity_level': act,
            'experience_level': exp, 'workout_split': split
        })

    return pd.DataFrame(data)


def evaluate_model():
    print("=" * 70)
    print("FITCORE ML MODEL COMPREHENSIVE EVALUATION")
    print("=" * 70)

    # Generate data WITH noise
    df = generate_realistic_training_data(1500, noise_rate=0.08)

    X = df[['age', 'gender', 'bmi', 'fitness_goal', 'activity_level', 'experience_level']]
    y = df['workout_split']

    num_features = ['age', 'bmi']
    cat_features = ['gender', 'fitness_goal', 'activity_level', 'experience_level']

    preprocessor = ColumnTransformer(transformers=[
        ('num', StandardScaler(), num_features),
        ('cat', OneHotEncoder(handle_unknown='ignore'), cat_features)
    ])

    pipeline = Pipeline(steps=[
        ('preprocessor', preprocessor),
        ('classifier', RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42))
    ])

    # --- 1) Single Train/Test Split (80/20) ---
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)

    pipeline.fit(X_train, y_train)
    y_pred = pipeline.predict(X_test)

    acc = accuracy_score(y_test, y_pred)
    prec_macro, rec_macro, f1_macro, _ = precision_recall_fscore_support(y_test, y_pred, average='macro')
    prec_weighted, rec_weighted, f1_weighted, _ = precision_recall_fscore_support(y_test, y_pred, average='weighted')

    print(f"\n--- Single 80/20 Split Results ---")
    print(f"Test Set Size : {len(y_test)} samples")
    print(f"Accuracy      : {acc * 100:.2f}%")
    print(f"Precision (macro avg) : {prec_macro:.4f}")
    print(f"Recall    (macro avg) : {rec_macro:.4f}")
    print(f"F1-Score  (macro avg) : {f1_macro:.4f}")

    # Per-class report
    report_dict = classification_report(y_test, y_pred, output_dict=True)
    print("\n--- Per-Class Classification Report ---")
    print(classification_report(y_test, y_pred))

    # Confusion matrix
    labels = sorted(y.unique())
    cm = confusion_matrix(y_test, y_pred, labels=labels)
    print("--- Confusion Matrix ---")
    print(pd.DataFrame(cm, index=labels, columns=labels).to_string())

    # --- 2) Stratified 5-Fold Cross-Validation ---
    print(f"\n--- 5-Fold Stratified Cross-Validation ---")
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_scores = cross_val_score(pipeline, X, y, cv=cv, scoring='accuracy')
    print(f"Fold Accuracies : {[f'{s:.4f}' for s in cv_scores]}")
    print(f"Mean Accuracy   : {cv_scores.mean() * 100:.2f}% +/- {cv_scores.std() * 100:.2f}%")

    # --- 3) Feature Importance ---
    pipeline.fit(X, y)
    clf = pipeline.named_steps['classifier']
    ohe = pipeline.named_steps['preprocessor'].named_transformers_['cat']
    cat_names = list(ohe.get_feature_names_out(cat_features))
    feature_names = num_features + cat_names
    importances = clf.feature_importances_
    feat_imp = sorted(zip(feature_names, importances), key=lambda x: x[1], reverse=True)

    print(f"\n--- Feature Importance (Top 15) ---")
    for name, imp in feat_imp[:15]:
        bar = '#' * int(imp * 100)
        print(f"  {name:40s} {imp:.4f} {bar}")

    # --- 4) Save results as JSON ---
    results = {
        "model": "RandomForestClassifier",
        "hyperparameters": {
            "n_estimators": 100,
            "max_depth": 10,
            "random_state": 42
        },
        "dataset": {
            "total_samples": len(df),
            "training_samples": len(X_train),
            "test_samples": len(X_test),
            "split_ratio": "80/20",
            "noise_rate": "8%",
            "num_classes": len(labels),
            "class_names": labels
        },
        "single_split_metrics": {
            "accuracy": round(acc, 4),
            "precision_macro": round(prec_macro, 4),
            "recall_macro": round(rec_macro, 4),
            "f1_score_macro": round(f1_macro, 4),
            "precision_weighted": round(prec_weighted, 4),
            "recall_weighted": round(rec_weighted, 4),
            "f1_score_weighted": round(f1_weighted, 4),
        },
        "cross_validation": {
            "method": "StratifiedKFold",
            "n_splits": 5,
            "fold_scores": [round(s, 4) for s in cv_scores],
            "mean_accuracy": round(cv_scores.mean(), 4),
            "std_accuracy": round(cv_scores.std(), 4),
        },
        "per_class_report": {k: v for k, v in report_dict.items() if k not in ['accuracy', 'macro avg', 'weighted avg']},
        "confusion_matrix": cm.tolist(),
        "confusion_matrix_labels": labels,
        "feature_importance_top15": [{"feature": n, "importance": round(v, 4)} for n, v in feat_imp[:15]],
    }

    out_path = os.path.join(os.path.dirname(__file__), 'evaluation_results.json')
    with open(out_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nEvaluation results saved to: {out_path}")

    return results


if __name__ == '__main__':
    evaluate_model()
