# FITCORE ML & Optimization Microservice

Companion AI & Operations Research microservice for the **Gym Management, Workout and Meal Plan Recommendation System**.

## Academic Defense Architecture (ML + Optimization Distinction)

| Engine | Technique | Academic Justification |
|---|---|---|
| **Workout Recommender** | Machine Learning (scikit-learn `RandomForestClassifier` + `Pipeline`) | Probabilistic classification: predicts the optimal workout split (`Push-Pull-Legs`, `Upper-Lower`, `Full-Body`, `Cardio-HIIT`) based on historical biometric training data, goals, and experience. |
| **Meal Plan Generator** | Mathematical Optimization (Linear / Integer Programming via `PuLP`) | Deterministic constraint satisfaction: solves the classic **Diet Problem** to guarantee target calories and macro ranges while strictly excluding allergens and adhering to budget constraints. |

---

## Model Evaluation Metrics

Evaluated with **1,500 samples** (8% noise injection) using **80/20 stratified split** and **5-fold cross-validation**.

| Metric | Value |
|---|---|
| Accuracy | 92.33% |
| Precision (macro avg) | 91.84% |
| Recall (macro avg) | 90.60% |
| F1-Score (macro avg) | 91.13% |
| 5-Fold Cross-Val Mean | 92.67% ± 1.03% |

Run `python train_model.py` to retrain and regenerate these metrics.

---

## Dataset

### Workout Training Data
- **1,500 synthetic gym user profiles** with ACSM-based ground truth labeling
- Features: `age`, `gender`, `bmi`, `fitness_goal`, `activity_level`, `experience_level`
- Target: 7 workout split classes
- 8% label noise for realistic evaluation

### Food Dataset
- **52 Filipino-friendly food items** across Breakfast, Lunch, Dinner, Snack
- Includes: Tinola, Sinigang, Adobo, Pinakbet, Bangus, Kamote, Monggo, Taho, etc.
- Each item: calories, protein, carbs, fat, cost (₱), serving unit, allergens

---

## Getting Started

### 1. Install Dependencies
```bash
python -m pip install -r requirements.txt
```

### 2. Train the Workout Recommender Model
```bash
python train_model.py
```
This generates `app/models/workout_classifier.joblib` and `evaluation_results.json`.

### 3. Run the Microservice
```bash
uvicorn app.main:app --reload --port 8000
```
Interactive Swagger API documentation will be available at `http://127.0.0.1:8000/docs`.

---

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/health` | Microservice status and active engine details |
| `GET` | `/model-metrics` | ML model evaluation results (accuracy, precision, recall, F1, confusion matrix, feature importance) |
| `POST` | `/recommend-workout` | Body accepts age, gender, height, weight, goal, activity level, and injury flags |
| `POST` | `/generate-meal-plan` | Body accepts target calories, macro ratios, dietary restrictions (allergens), and budget limits |

---

## Jupyter Notebooks

| Notebook | Contents |
|---|---|
| `01_data_preprocessing.ipynb` | Data generation, BMI distributions, feature encoding, class balance analysis |
| `02_model_training.ipynb` | Training, classification report, confusion matrix, cross-validation, feature importance |
| `03_lp_model_prototype.ipynb` | LP formulation, PuLP solver, constraint verification, LP vs heuristic comparison |
