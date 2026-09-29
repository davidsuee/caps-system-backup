from fastapi import APIRouter, HTTPException
from app.schemas.workout_schema import WorkoutRecommendationRequest, WorkoutRecommendationResponse
from app.services.ml_service import ml_service

router = APIRouter(prefix="", tags=["Workout ML Recommender"])

@router.post("/recommend-workout", response_model=WorkoutRecommendationResponse)
def recommend_workout(request: WorkoutRecommendationRequest):
    try:
        return ml_service.recommend(request)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ML Workout Recommender error: {str(e)}")
