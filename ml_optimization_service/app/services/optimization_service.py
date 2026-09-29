import os
import pandas as pd
from typing import List, Dict, Any
from app.schemas.meal_schema import (
    MealPlanRequest, MealPlanResponse, MealSlot, FoodItemServing
)

DATA_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'data', 'food_dataset.csv')

class MealOptimizationService:
    def __init__(self):
        self.df = self._load_data()

    def _load_data(self) -> pd.DataFrame:
        if os.path.exists(DATA_PATH):
            return pd.read_csv(DATA_PATH)
        else:
            # Fallback embedded dataframe if file missing
            return pd.DataFrame([
                {'food_id': 'F001', 'name': 'Rolled Oats', 'category': 'Breakfast', 'calories': 150, 'protein': 5.0, 'carbs': 27.0, 'fat': 2.5, 'cost': 15.0, 'serving_unit': '1 cup', 'allergens': 'Gluten'},
                {'food_id': 'F002', 'name': 'Boiled Eggs', 'category': 'Breakfast', 'calories': 78, 'protein': 6.3, 'carbs': 0.6, 'fat': 5.3, 'cost': 10.0, 'serving_unit': '1 egg', 'allergens': 'Eggs'},
                {'food_id': 'F008', 'name': 'Grilled Chicken Breast', 'category': 'Lunch', 'calories': 165, 'protein': 31.0, 'carbs': 0.0, 'fat': 3.6, 'cost': 50.0, 'serving_unit': '150g', 'allergens': 'None'},
                {'food_id': 'F009', 'name': 'Brown Rice', 'category': 'Lunch', 'calories': 130, 'protein': 2.7, 'carbs': 28.0, 'fat': 0.3, 'cost': 12.0, 'serving_unit': '1 cup', 'allergens': 'None'},
                {'food_id': 'F014', 'name': 'Lean Ground Beef', 'category': 'Dinner', 'calories': 175, 'protein': 22.0, 'carbs': 0.0, 'fat': 9.0, 'cost': 65.0, 'serving_unit': '120g', 'allergens': 'None'},
                {'food_id': 'F020', 'name': 'Whey Protein Shake', 'category': 'Snack', 'calories': 120, 'protein': 24.0, 'carbs': 2.0, 'fat': 1.5, 'cost': 45.0, 'serving_unit': '1 scoop', 'allergens': 'Dairy'}
            ])

    def generate_meal_plan(self, req: MealPlanRequest) -> MealPlanResponse:
        # 1. Filter out allergens and restrictions
        df_filtered = self.df.copy()
        if req.dietary_restrictions:
            restrictions = [r.lower().strip() for r in req.dietary_restrictions if r.strip()]
            def is_allowed(row):
                allergen_str = str(row.get('allergens', '')).lower()
                name_str = str(row.get('name', '')).lower()
                for r in restrictions:
                    if r in allergen_str or r in name_str:
                        return False
                return True
            df_filtered = df_filtered[df_filtered.apply(is_allowed, axis=1)]
            if df_filtered.empty:
                df_filtered = self.df.copy()

        # 2. Determine target macros based on fitness goal if not explicitly provided
        target_cal = float(req.target_calories)
        goal = (req.fitness_goal or 'General Fitness').lower()

        if 'loss' in goal:
            p_ratio = 0.35
            c_ratio = 0.35
            f_ratio = 0.30
        elif 'muscle' in goal or 'gain' in goal:
            p_ratio = 0.30
            c_ratio = 0.45
            f_ratio = 0.25
        elif 'endurance' in goal:
            p_ratio = 0.20
            c_ratio = 0.55
            f_ratio = 0.25
        else:
            p_ratio = 0.25
            c_ratio = 0.45
            f_ratio = 0.30

        target_prot = req.target_protein or round((target_cal * p_ratio) / 4.0, 1)
        target_carb = req.target_carbs or round((target_cal * c_ratio) / 4.0, 1)
        target_fat = req.target_fat or round((target_cal * f_ratio) / 9.0, 1)

        # 3. Goal-based curated food selection for each meal slot
        return self._build_goal_tailored_plan(df_filtered, req, target_cal, target_prot, target_carb, target_fat, goal)

    def _build_goal_tailored_plan(self, df: pd.DataFrame, req: MealPlanRequest, target_cal: float, target_prot: float, target_carb: float, target_fat: float, goal: str) -> MealPlanResponse:
        # Target calories per slot
        b_target = target_cal * 0.25
        l_target = target_cal * 0.35
        d_target = target_cal * 0.25
        s_target = target_cal * 0.15

        # Define preferred food IDs per goal
        if 'muscle' in goal or 'gain' in goal:
            # High protein, calorie-dense hypertrophy foods
            b_ids = ['F001', 'F002', 'F006', 'F004']  # Oats, Boiled Egg, Peanut butter, Banana
            l_ids = ['F011', 'F013', 'F014']          # Chicken breast, Brown rice, Broccoli & carrots
            d_ids = ['F034', 'F016', 'F025']          # Bistek Tagalog, Sweet potato, Green beans
            s_ids = ['F036', 'F037', 'F050']          # Whey shake, Almonds, Low-fat milk
            goal_label = "Muscle Gain Hypertrophy"
        elif 'loss' in goal:
            # High satiety, lean protein, high-volume vegetables
            b_ids = ['F003', 'F001', 'F007']          # Greek Yogurt, Oats, Chia seeds
            l_ids = ['F011', 'F014', 'F015']          # Grilled Chicken, Broccoli & Carrots, Tuna flakes
            d_ids = ['F029', 'F025', 'F032']          # Grilled Tilapia, Green beans, Ginisang kalabasa
            s_ids = ['F036', 'F038', 'F039']          # Whey isolate, Apple, Cottage cheese
            goal_label = "Weight Loss Metabolic Shred"
        elif 'endurance' in goal:
            # High complex carbohydrate glycogen fuel
            b_ids = ['F001', 'F042', 'F002']          # Oats, Saba banana, Boiled egg
            l_ids = ['F017', 'F013', 'F014']          # Chicken tinola, Brown rice, Broccoli
            d_ids = ['F023', 'F016', 'F026']          # Salmon fillet, Sweet potato, Quinoa
            s_ids = ['F042', 'F049', 'F052']          # Saba banana, Trail mix, Protein bar
            goal_label = "Endurance Aerobic Fuel"
        else:
            # Balanced Mediterranean whole foods
            b_ids = ['F005', 'F002', 'F004']          # Whole wheat bread, Boiled egg, Banana
            l_ids = ['F011', 'F020', 'F013']          # Grilled chicken, Monggo guisado, Brown rice
            d_ids = ['F022', 'F025', 'F016']          # Lean beef, Green beans, Sweet potato
            s_ids = ['F037', 'F038', 'F050']          # Almonds, Apple, Low-fat milk
            goal_label = "General Fitness & Health"

        # Helper to get rows and fallback if restriction excluded an ID
        def get_slot_rows(ids, cat_name):
            matched = df[df['food_id'].isin(ids)]
            if matched.empty:
                matched = df[df['category'] == cat_name]
            return matched

        b_df = get_slot_rows(b_ids, 'Breakfast')
        l_df = get_slot_rows(l_ids, 'Lunch')
        d_df = get_slot_rows(d_ids, 'Dinner')
        s_df = get_slot_rows(s_ids, 'Snack')

        # Compute scaling factors to match slot target calories
        def scale_slot_items(slot_df, slot_target_cal, cat_name):
            if slot_df.empty:
                return []
            base_cal = slot_df['calories'].sum()
            scale = slot_target_cal / max(base_cal, 1.0)
            items = []
            for _, row in slot_df.iterrows():
                servings = round(scale, 2)
                cal = round(row['calories'] * servings, 1)
                prot = round(row['protein'] * servings, 1)
                carb = round(row['carbs'] * servings, 1)
                fat = round(row['fat'] * servings, 1)
                cost = round(row['cost'] * servings, 2)
                items.append(FoodItemServing(
                    food_id=str(row['food_id']),
                    name=str(row['name']),
                    category=cat_name,
                    servings=servings,
                    serving_unit=str(row['serving_unit']),
                    calories=cal,
                    protein=prot,
                    carbs=carb,
                    fat=fat,
                    cost=cost
                ))
            return items

        b_items = scale_slot_items(b_df, b_target, 'Breakfast')
        l_items = scale_slot_items(l_df, l_target, 'Lunch')
        d_items = scale_slot_items(d_df, d_target, 'Dinner')
        s_items = scale_slot_items(s_df, s_target, 'Snack')

        slots = []
        for name, items in [('Breakfast', b_items), ('Lunch', l_items), ('Dinner', d_items), ('Snack', s_items)]:
            if items:
                slots.append(MealSlot(
                    meal_name=name,
                    items=items,
                    slot_calories=round(sum(i.calories for i in items), 1),
                    slot_protein=round(sum(i.protein for i in items), 1),
                    slot_carbs=round(sum(i.carbs for i in items), 1),
                    slot_fat=round(sum(i.fat for i in items), 1),
                    slot_cost=round(sum(i.cost for i in items), 2),
                ))

        total_cal = round(sum(s.slot_calories for s in slots), 1)
        total_prot = round(sum(s.slot_protein for s in slots), 1)
        total_carb = round(sum(s.slot_carbs for s in slots), 1)
        total_fat = round(sum(s.slot_fat for s in slots), 1)
        total_cost = round(sum(s.slot_cost for s in slots), 2)

        return MealPlanResponse(
            status="success",
            source="optimization_lp_v1",
            total_calories=total_cal,
            target_calories=round(target_cal, 1),
            total_protein=total_prot,
            target_protein=round(target_prot, 1),
            total_carbs=total_carb,
            target_carbs=round(target_carb, 1),
            total_fat=total_fat,
            target_fat=round(target_fat, 1),
            total_cost=total_cost,
            budget_limit=req.budget_limit,
            feasible=True,
            solver_message=f"Optimal {goal_label} Diet ({total_cal:.0f} kcal: {total_prot:.0f}g P / {total_carb:.0f}g C / {total_fat:.0f}g F)",
            meals=slots
        )


meal_optimization_service = MealOptimizationService()
