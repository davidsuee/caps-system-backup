from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.routers import workout_router, meal_router, metrics_router

app = FastAPI(
    title="FITCORE ML & Optimization Microservice",
    description="Machine Learning workout split recommendation and Linear Programming diet optimization service for Gym Management System.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(workout_router.router)
app.include_router(meal_router.router)
app.include_router(metrics_router.router)

@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "online",
        "service": "FITCORE ML & Optimization Microservice",
        "engines": {
            "workout_engine": "scikit-learn RandomForest Classifier Pipeline",
            "meal_engine": "PuLP / Simplex Linear Programming Solver"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
