from typing import List, Optional
from pydantic import BaseModel, Field

class MealPlanRequest(BaseModel):
    user_id: Optional[str] = "guest"
    target_calories: float = Field(gt=1000, lt=5000, description="Target daily caloric intake")
    target_protein: Optional[float] = Field(default=None, description="Target protein in grams")
    target_carbs: Optional[float] = Field(default=None, description="Target carbohydrates in grams")
    target_fat: Optional[float] = Field(default=None, description="Target fats in grams")
    fitness_goal: Optional[str] = Field(default="General Fitness", description="Fitness Goal: Weight Loss, Muscle Gain, Improve Endurance, General Fitness")
    dietary_restrictions: List[str] = Field(default_factory=list, description="Allergens/restrictions: Gluten, Dairy, Nuts, Eggs, Seafood")
    budget_limit: Optional[float] = Field(default=None, description="Maximum total cost limit for daily meals")
    meals_per_day: int = Field(default=4, ge=3, le=5, description="Number of meals (3 to 5)")

class FoodItemServing(BaseModel):
    food_id: str
    name: str
    category: str
    servings: float
    serving_unit: str
    calories: float
    protein: float
    carbs: float
    fat: float
    cost: float

class MealSlot(BaseModel):
    meal_name: str
    items: List[FoodItemServing]
    slot_calories: float
    slot_protein: float
    slot_carbs: float
    slot_fat: float
    slot_cost: float

class MealPlanResponse(BaseModel):
    status: str = "success"
    source: str = "optimization_lp_v1"
    total_calories: float
    target_calories: float
    total_protein: float
    target_protein: float
    total_carbs: float
    target_carbs: float
    total_fat: float
    target_fat: float
    total_cost: float
    budget_limit: Optional[float] = None
    feasible: bool = True
    solver_message: str
    meals: List[MealSlot]
