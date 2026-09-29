from typing import List, Optional
from pydantic import BaseModel, Field

class WorkoutRecommendationRequest(BaseModel):
    user_id: Optional[str] = "guest"
    age: int = Field(ge=14, le=85, description="Age of the user")
    gender: str = Field(description="Male, Female, or Other")
    height_cm: float = Field(gt=100, lt=250, description="Height in centimeters")
    weight_kg: float = Field(gt=30, lt=300, description="Weight in kilograms")
    fitness_goal: str = Field(description="Weight Loss, Muscle Gain, Improve Endurance, General Fitness")
    activity_level: str = Field(description="Sedentary, Lightly Active, Moderately Active, Very Active")
    experience_level: str = Field(default="Beginner", description="Beginner, Intermediate, Advanced")
    available_equipment: List[str] = Field(default_factory=lambda: ["Full Gym"], description="Available workout equipment")
    injury_flags: List[str] = Field(default_factory=list, description="List of injuries or limitations (e.g. knee, lower_back, shoulder)")

class ExerciseItem(BaseModel):
    name: str
    muscle_group: str
    sets: str
    reps: str
    rest_sec: int
    equipment: str
    instructions: Optional[str] = ""
    day_tag: Optional[str] = ""

class WorkoutRecommendationResponse(BaseModel):
    status: str = "success"
    recommended_split: str
    confidence_score: float
    source: str = "ml_model_v1"
    summary: str
    routine: List[ExerciseItem]
    warning: Optional[str] = None
