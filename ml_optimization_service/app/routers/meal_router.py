from fastapi import APIRouter, HTTPException
from app.schemas.meal_schema import MealPlanRequest, MealPlanResponse
from app.services.optimization_service import meal_optimization_service

router = APIRouter(prefix="", tags=["Meal LP Optimizer"])

@router.post("/generate-meal-plan", response_model=MealPlanResponse)
def generate_meal_plan(request: MealPlanRequest):
    try:
        return meal_optimization_service.generate_meal_plan(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Meal LP Optimizer error: {str(e)}")
