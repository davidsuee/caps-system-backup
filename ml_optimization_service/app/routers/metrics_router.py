import os
import json
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="", tags=["ML Model Metrics"])

EVAL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), '..', 'evaluation_results.json')

@router.get("/model-metrics", summary="Get ML model evaluation metrics")
def get_model_metrics():
    """
    Returns the complete evaluation results of the trained Random Forest
    Classifier including accuracy, precision, recall, F1-score,
    cross-validation scores, confusion matrix, and feature importance.
    """
    abs_path = os.path.abspath(EVAL_PATH)
    if not os.path.exists(abs_path):
        raise HTTPException(
            status_code=404,
            detail="Evaluation results not found. Run 'python train_model.py' first to generate metrics."
        )
    
    with open(abs_path, 'r') as f:
        metrics = json.load(f)
    
    return metrics
