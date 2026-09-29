# A Gym Management, Workout and Meal Plan Recommendation System using Optimization and Machine Learning

**Comprehensive System & Development Plan**
Tech Stack: **Flutter (Frontend/Mobile) + Firebase (Backend-as-a-Service) + Python (ML/Optimization microservice)**

---

## 1. Project Overview

### 1.1 Problem Statement
Gym-goers struggle to get personalized workout and meal plans that fit their body metrics, goals, equipment access, dietary restrictions, and budget. Gym owners/trainers, meanwhile, lack a unified system to manage memberships, schedules, and client progress. This system solves both sides:

- **For members**: AI/optimization-driven workout routines and meal plans tailored to their profile.
- **For gym admins/trainers**: Membership management, attendance, billing, and client monitoring.

### 1.2 Core Modules
1. **Authentication & User Profiles** (Member, Trainer, Admin roles)
2. **Gym Management** (membership plans, subscriptions, check-in/attendance, payments)
3. **Workout Recommendation Engine** (ML-based, considers goals, fitness level, equipment, injury history)
4. **Meal Plan Recommendation Engine** (optimization-based — e.g., linear programming to hit macro/calorie targets within food preferences and budget)
5. **Progress Tracking** (weight, body measurements, workout logs, photos)
6. **Admin Dashboard** (analytics, revenue, member retention)
7. **Notifications** (class reminders, plan renewal, workout reminders)

### 1.3 Why "Optimization AND Machine Learning" (the two engines)
This is the academic core of your capstone — panels will look for this distinction:

| Engine | Technique | Purpose |
|---|---|---|
| **Workout Recommender** | Machine Learning — Content-based filtering / Collaborative filtering / Random Forest classifier | Predicts *which exercises/routines* suit a user based on similar user profiles & historical outcomes |
| **Meal Plan Generator** | Mathematical Optimization — Linear Programming (LP) / Integer Programming via a solver (e.g., PuLP, OR-Tools) | *Generates* a meal combination that satisfies hard constraints (calories, macros, allergies, budget) — this is a constrained search problem, not a prediction problem, so optimization fits better than ML here |

This ML+Optimization hybrid is your thesis's defensible novelty: recommendation (ML) for workouts, constraint-satisfaction (Optimization) for meals.

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     FLUTTER APP (Client)                     │
│   Member App    |    Trainer App    |    Admin Web/App       │
└───────────────────────────┬──────────────────────────────────┘
                             │ (Firebase SDK / REST)
              ┌──────────────┴───────────────┐
              │                               │
   ┌──────────▼─────────┐         ┌───────────▼────────────┐
   │      FIREBASE       │         │   ML/OPTIMIZATION API   │
   │ - Authentication     │         │  (Python - FastAPI/     │
   │ - Firestore (DB)     │◄───────►│   Cloud Run / Cloud     │
   │ - Cloud Storage       │         │   Functions)            │
   │ - Cloud Functions     │         │ - scikit-learn model    │
   │ - Cloud Messaging(FCM)│         │ - PuLP/OR-Tools solver   │
   │ - Firebase Hosting    │         └─────────────────────────┘
   └───────────────────────┘
```

**Why a separate ML/Optimization service?** Firebase Cloud Functions (Node/Python) can host lightweight logic, but scikit-learn models and LP solvers are heavier — best deployed as a dedicated Python microservice (FastAPI) on **Cloud Run**, which Firebase Functions can call via HTTPS, or the Flutter app can call directly with the user's Firebase Auth token for verification.

---

## 3. Tech Stack Breakdown

| Layer | Technology | Notes |
|---|---|---|
| Mobile/Web Frontend | **Flutter 3.x (Dart)** | Single codebase for Android/iOS, optionally web for admin |
| State Management | **Riverpod** (or Bloc) | Riverpod recommended for scalability + testability |
| Backend/Database | **Firebase Firestore** | NoSQL, real-time sync |
| Auth | **Firebase Authentication** | Email/password + Google Sign-In |
| File/Image Storage | **Firebase Cloud Storage** | Profile photos, progress photos |
| Serverless Logic | **Firebase Cloud Functions** (Node.js or Python) | Triggers: subscription expiry, notifications |
| ML/Optimization Service | **Python + FastAPI**, hosted on **Cloud Run** | scikit-learn (ML), PuLP or Google OR-Tools (optimization) |
| Push Notifications | **Firebase Cloud Messaging (FCM)** | Reminders, renewal alerts |
| Analytics | **Firebase Analytics + Crashlytics** | Usage tracking, crash reports |
| CI/CD | **Codemagic / GitHub Actions** | Automated builds |
| Payments (optional) | **PayMongo / Stripe** via Cloud Functions | Membership billing |

---

## 4. Data Modeling (Firestore Collections)

```
users (collection)
 └── {uid} (doc)
      - name, email, role: "member" | "trainer" | "admin"
      - age, sex, height_cm, weight_kg, activity_level
      - fitness_goal: "lose_weight" | "gain_muscle" | "maintain"
      - dietary_restrictions: [array]
      - equipment_access: [array]
      - createdAt

memberships (collection)
 └── {membershipId}
      - userId, plan_type, start_date, end_date, status, amount_paid

attendance (collection)
 └── {attendanceId}
      - userId, checkInTime, checkOutTime

workout_plans (collection)
 └── {planId}
      - userId, generatedAt, goal, difficulty
      - exercises: [ { name, sets, reps, restSec, muscleGroup, equipment } ]
      - source: "ml_model_v1"

meal_plans (collection)
 └── {planId}
      - userId, generatedAt, targetCalories, targetMacros {protein, carbs, fat}
      - meals: [ { name, foodItems: [...], totalCalories, cost } ]
      - source: "optimization_lp_v1"

progress_logs (collection)
 └── {logId}
      - userId, date, weight_kg, bodyFatPercent, photos: [urls], notes

exercise_library (collection)
 └── {exerciseId}
      - name, muscleGroup, equipmentNeeded, difficulty, videoUrl, caloriesBurnEstimate

food_library (collection)
 └── {foodId}
      - name, caloriesPer100g, protein, carbs, fat, costPerUnit, category, allergens
```

---

## 5. ML & Optimization Design

### 5.1 Workout Recommendation (Machine Learning)
- **Approach**: Content-based filtering + a trained classifier (Random Forest / Gradient Boosting) to map user profile → suitable workout split (e.g., Push/Pull/Legs vs Full Body vs Upper/Lower).
- **Features**: age, sex, BMI, fitness_goal, activity_level, available_equipment, experience_level, injury_flags.
- **Label/Target**: workout template category (from a curated dataset you build — e.g., labeled by trainers or scraped/curated from ACSM guidelines).
- **Pipeline**: scikit-learn `Pipeline` (StandardScaler → OneHotEncoder → Classifier), exported with `joblib`, served via FastAPI `/recommend-workout` endpoint.
- **Fallback**: rule-based logic if confidence score is low (important for defense — show you handled edge cases).

### 5.2 Meal Plan Recommendation (Optimization)
- **Approach**: Linear/Integer Programming — the classic "diet problem."
- **Objective function**: Minimize cost (or maximize variety/preference score) subject to nutritional constraints.
- **Constraints**:
  - `Σ calories = target_calories ± tolerance`
  - `Σ protein ≥ min_protein`, `Σ carbs`, `Σ fat` within target macro ranges
  - Exclude foods matching `dietary_restrictions`/`allergens`
  - `total_cost ≤ user_budget` (optional)
  - Serving-count integer constraints
- **Tooling**: `PuLP` (simplest, pure-Python, CBC solver) or `Google OR-Tools` (more robust for larger food libraries).
- **Output**: a combination of items from `food_library` forming breakfast/lunch/dinner/snacks that satisfy all constraints.

### 5.3 Why This Matters for Your Defense
Be ready to explain: ML predicts a *category/pattern* from historical/labeled data (probabilistic), while optimization *solves* a constrained system for a *guaranteed feasible* numeric solution — that's the academic justification for using both techniques rather than just ML for everything.

---

## 6. Flutter App — Folder Structure (Clean Architecture + Feature-First)

```
gym_app/
├── android/
├── ios/
├── web/                              # optional, for admin dashboard
├── assets/
│   ├── images/
│   ├── icons/
│   └── lottie/
├── lib/
│   ├── main.dart
│   ├── app.dart                      # MaterialApp, theming, routing setup
│   │
│   ├── core/                         # Shared, app-wide code
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   ├── app_strings.dart
│   │   │   └── app_routes.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   ├── utils/
│   │   │   ├── validators.dart
│   │   │   ├── date_utils.dart
│   │   │   └── bmi_calculator.dart
│   │   ├── errors/
│   │   │   ├── exceptions.dart
│   │   │   └── failures.dart
│   │   ├── network/
│   │   │   ├── api_client.dart       # calls to ML/Optimization microservice
│   │   │   └── network_info.dart
│   │   └── widgets/                  # shared reusable widgets
│   │       ├── custom_button.dart
│   │       ├── custom_textfield.dart
│   │       ├── loading_indicator.dart
│   │       └── error_view.dart
│   │
│   ├── config/
│   │   ├── firebase_options.dart     # generated by flutterfire CLI
│   │   └── env.dart                  # API base URLs, keys
│   │
│   ├── data/                         # Data layer
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── membership_model.dart
│   │   │   ├── workout_plan_model.dart
│   │   │   ├── meal_plan_model.dart
│   │   │   ├── exercise_model.dart
│   │   │   └── food_model.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository_impl.dart
│   │   │   ├── user_repository_impl.dart
│   │   │   ├── membership_repository_impl.dart
│   │   │   ├── workout_repository_impl.dart
│   │   │   └── meal_repository_impl.dart
│   │   └── datasources/
│   │       ├── remote/
│   │       │   ├── firebase_auth_service.dart
│   │       │   ├── firestore_service.dart
│   │       │   ├── storage_service.dart
│   │       │   └── recommendation_api_service.dart   # calls FastAPI ML/Opt service
│   │       └── local/
│   │           └── local_cache_service.dart           # e.g., shared_preferences/hive
│   │
│   ├── domain/                       # Business logic layer
│   │   ├── entities/
│   │   │   ├── user_entity.dart
│   │   │   ├── workout_plan_entity.dart
│   │   │   └── meal_plan_entity.dart
│   │   ├── repositories/             # abstract interfaces
│   │   │   ├── auth_repository.dart
│   │   │   ├── workout_repository.dart
│   │   │   └── meal_repository.dart
│   │   └── usecases/
│   │       ├── sign_in_usecase.dart
│   │       ├── sign_up_usecase.dart
│   │       ├── generate_workout_plan_usecase.dart
│   │       ├── generate_meal_plan_usecase.dart
│   │       ├── log_progress_usecase.dart
│   │       └── check_in_usecase.dart
│   │
│   ├── presentation/                 # UI layer (feature-first)
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── register_screen.dart
│   │   │   │   └── onboarding_profile_screen.dart
│   │   │   ├── providers/            # Riverpod providers/notifiers
│   │   │   │   └── auth_provider.dart
│   │   │   └── widgets/
│   │   │
│   │   ├── dashboard/
│   │   │   ├── screens/
│   │   │   │   └── home_dashboard_screen.dart
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   │
│   │   ├── workout/
│   │   │   ├── screens/
│   │   │   │   ├── workout_plan_screen.dart
│   │   │   │   ├── exercise_detail_screen.dart
│   │   │   │   └── workout_log_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── workout_provider.dart
│   │   │   └── widgets/
│   │   │       ├── exercise_card.dart
│   │   │       └── workout_progress_chart.dart
│   │   │
│   │   ├── meal/
│   │   │   ├── screens/
│   │   │   │   ├── meal_plan_screen.dart
│   │   │   │   └── meal_detail_screen.dart
│   │   │   ├── providers/
│   │   │   │   └── meal_provider.dart
│   │   │   └── widgets/
│   │   │       └── meal_card.dart
│   │   │
│   │   ├── membership/
│   │   │   ├── screens/
│   │   │   │   ├── membership_plans_screen.dart
│   │   │   │   ├── payment_screen.dart
│   │   │   │   └── attendance_screen.dart
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   │
│   │   ├── progress/
│   │   │   ├── screens/
│   │   │   │   └── progress_tracking_screen.dart
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   │       └── progress_chart.dart
│   │   │
│   │   ├── admin/                    # trainer/admin-only views
│   │   │   ├── screens/
│   │   │   │   ├── admin_dashboard_screen.dart
│   │   │   │   ├── manage_members_screen.dart
│   │   │   │   └── analytics_screen.dart
│   │   │   ├── providers/
│   │   │   └── widgets/
│   │   │
│   │   └── profile/
│   │       ├── screens/
│   │       │   └── profile_screen.dart
│   │       ├── providers/
│   │       └── widgets/
│   │
│   └── routing/
│       └── app_router.dart           # go_router configuration
│
├── test/
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── pubspec.yaml
└── firebase.json

# Separate repo/folder for the ML/Optimization microservice:
ml_optimization_service/
├── app/
│   ├── main.py                       # FastAPI entrypoint
│   ├── routers/
│   │   ├── workout_router.py         # POST /recommend-workout
│   │   └── meal_router.py            # POST /generate-meal-plan
│   ├── models/
│   │   └── workout_classifier.joblib # trained sklearn model
│   ├── services/
│   │   ├── ml_service.py             # loads model, predicts
│   │   └── optimization_service.py   # PuLP/OR-Tools LP solver logic
│   ├── schemas/
│   │   ├── workout_schema.py         # Pydantic request/response models
│   │   └── meal_schema.py
│   └── data/
│       └── food_dataset.csv
├── notebooks/
│   ├── 01_data_preprocessing.ipynb
│   ├── 02_model_training.ipynb
│   └── 03_lp_model_prototype.ipynb
├── requirements.txt
├── Dockerfile
└── README.md
```

---

## 7. Development Roadmap (Suggested for a 1-Semester Capstone)

| Phase | Duration | Deliverables |
|---|---|---|
| **Phase 1 — Planning & Design** | Weeks 1–3 | Finalize SRS, ERD, Firestore schema, wireframes/Figma, dataset sourcing |
| **Phase 2 — Core Setup** | Weeks 4–5 | Flutter project scaffold (folder structure above), Firebase project setup, Auth flow |
| **Phase 3 — Gym Management Module** | Weeks 6–7 | Membership CRUD, attendance check-in, admin dashboard basics |
| **Phase 4 — ML Model Development** | Weeks 6–8 (parallel) | Data cleaning, train/test workout classifier, evaluate accuracy/F1 |
| **Phase 5 — Optimization Module** | Weeks 8–9 (parallel) | Build & test LP model for meal plans (PuLP), validate feasibility edge cases |
| **Phase 6 — API Integration** | Week 10 | Deploy FastAPI service to Cloud Run, connect Flutter → API |
| **Phase 7 — Progress Tracking & Notifications** | Week 11 | Logging screens, charts (fl_chart), FCM setup |
| **Phase 8 — Testing** | Week 12 | Unit tests, widget tests, user acceptance testing (UAT), model evaluation metrics |
| **Phase 9 — Deployment & Documentation** | Weeks 13–14 | Play Store/TestFlight build, final manuscript (Chapters 4–5), user manual |
| **Phase 10 — Defense Prep** | Week 15 | Slides, live demo script, anticipate panel questions on ML/optimization choices |

---

## 8. Key Flutter Packages

```yaml
dependencies:
  flutter_riverpod: ^2.5.1
  firebase_core: ^3.x
  firebase_auth: ^5.x
  cloud_firestore: ^5.x
  firebase_storage: ^12.x
  firebase_messaging: ^15.x
  go_router: ^14.x
  dio: ^5.x                    # HTTP client for ML/Optimization API
  fl_chart: ^0.68.0            # progress/analytics charts
  cached_network_image: ^3.x
  image_picker: ^1.x
  intl: ^0.19.0
  freezed_annotation: ^2.x     # immutable models
  json_annotation: ^4.x

dev_dependencies:
  build_runner: ^2.x
  freezed: ^2.x
  json_serializable: ^6.x
  mocktail: ^1.x                # for unit testing
```

---

## 9. Evaluation Metrics (for your Results chapter)

- **Workout ML Model**: Accuracy, Precision/Recall, F1-score, Confusion Matrix (train/test split, e.g., 80/20; consider k-fold cross-validation)
- **Meal Optimization**: Constraint satisfaction rate, average deviation from target macros, solver runtime, cost efficiency
- **System Usability**: ISO 25010-based questionnaire or System Usability Scale (SUS) survey with target users
- **App Performance**: Load time, Firestore read/write latency, crash-free rate (via Crashlytics)

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Small/insufficient labeled dataset for ML model | Use a hybrid: rule-based defaults + ML refinement; augment with synthetic data based on known fitness guidelines (ACSM/WHO) |
| LP solver infeasibility (no solution satisfies all constraints) | Add constraint relaxation/tolerance logic; return "closest feasible" plan |
| Firestore costs scaling with reads | Use pagination, caching, and composite indexes; avoid excessive real-time listeners |
| Panel questioning "why not just use ML for meals too" | Prepare the optimization-vs-ML justification (Section 5.3) clearly |

---

### Next Steps
I can help you build out any specific piece next — e.g., the actual Firestore security rules, the FastAPI meal-optimization code, the ML training notebook, or the Chapter 1–3 alignment with this technical plan (since your uploaded document covers the academic chapters). Let me know which part to start with.
