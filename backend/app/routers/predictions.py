import json
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import AIPrediction, Booking, QueueEntry
from ml_service.predictor import predict_wait
from backend.app.services.recommendation_engine import RecommendationEngine

router = APIRouter(prefix="/predictions", tags=["AI Prediction Service"])

class PredictionRequest(BaseModel):
    booking_id: Optional[int] = None
    centre_id: int
    quantity: float = 20.0
    farmers_ahead: int = 5
    active_counters: int = 2
    average_processing_time: float = 15.0
    current_processing_speed: float = 1.0
    time_of_day: int = 10
    day_of_week: int = 2
    seasonal_flag: int = 0
    no_show_rate: float = 0.1
    queue_growth_rate: float = 0.0
    equipment_status: int = 1
    operational_delay_flag: int = 0
    travel_time_minutes: float = 25.0

class PredictionResponse(BaseModel):
    id: Optional[int] = None
    centre_id: int
    predicted_wait_minutes: float
    rule_estimate: float
    model_estimate: float
    blend_weight_model: float
    confidence_score: float
    predicted_service_time_range: str
    recommended_arrival_time: str
    recommended_departure_time: str
    reasons: List[str]

@router.post("/waiting-time", response_model=PredictionResponse)
def get_predicted_waiting_time(
    request: PredictionRequest,
    db: Session = Depends(get_db)
):
    centre_history_count = db.query(QueueEntry).filter(
        QueueEntry.centre_id == request.centre_id,
        QueueEntry.status == "COMPLETED"
    ).count()

    features_dict = request.model_dump()
    result = predict_wait(features_dict, centre_history_count=centre_history_count)

    pred_wait = result["predicted_wait_minutes"]

    rec_data = RecommendationEngine.generate_recommendations(
        predicted_wait_minutes=pred_wait,
        slot_start_time="09:00",
        travel_time_minutes=request.travel_time_minutes,
        farmers_ahead=request.farmers_ahead,
        active_counters=request.active_counters,
        operational_delay_flag=request.operational_delay_flag
    )

    prediction_id = None
    if request.booking_id:
        ai_row = AIPrediction(
            booking_id=request.booking_id,
            centre_id=request.centre_id,
            predicted_wait_minutes=pred_wait,
            predicted_service_time_range=rec_data["predicted_service_time_range"],
            recommended_arrival_time=rec_data["recommended_arrival_time"],
            recommended_departure_time=rec_data["recommended_departure_time"],
            confidence_score=result["confidence_score"],
            dominant_features_json=json.dumps(rec_data["reasons"])
        )
        db.add(ai_row)
        db.commit()
        db.refresh(ai_row)
        prediction_id = ai_row.id

    return PredictionResponse(
        id=prediction_id,
        centre_id=request.centre_id,
        predicted_wait_minutes=pred_wait,
        rule_estimate=result["rule_estimate"],
        model_estimate=result["model_estimate"],
        blend_weight_model=result["blend_weight_model"],
        confidence_score=result["confidence_score"],
        predicted_service_time_range=rec_data["predicted_service_time_range"],
        recommended_arrival_time=rec_data["recommended_arrival_time"],
        recommended_departure_time=rec_data["recommended_departure_time"],
        reasons=rec_data["reasons"]
    )
