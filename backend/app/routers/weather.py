from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import ProcurementCentre
from backend.app.services.weather_service import WeatherService, TravelService

router = APIRouter(tags=["Weather & Travel Integration"])

class WeatherResponse(BaseModel):
    centre_id: int
    temperature_celsius: float
    humidity_percent: float
    weather_condition: str
    risk_level: str
    risk_summary: str
    source: str

class TravelTimeResponse(BaseModel):
    travel_time_minutes: float
    distance_km: float
    source: str

@router.get("/weather", response_model=WeatherResponse)
def get_centre_weather_info(
    centre_id: int = Query(..., description="Target Procurement Centre ID"),
    db: Session = Depends(get_db)
):
    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement Centre not found")

    w_data = WeatherService.get_centre_weather(
        centre_id=centre.id,
        lat=centre.latitude,
        lng=centre.longitude
    )
    return WeatherResponse(**w_data)

@router.get("/travel-time", response_model=TravelTimeResponse)
def get_travel_time_info(
    centre_id: int = Query(...),
    farmer_lat: float = Query(12.5218),
    farmer_lng: float = Query(76.8951),
    db: Session = Depends(get_db)
):
    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement Centre not found")

    t_data = TravelService.get_travel_time(
        centre_lat=centre.latitude,
        centre_lng=centre.longitude,
        farmer_lat=farmer_lat,
        farmer_lng=farmer_lng
    )
    return TravelTimeResponse(**t_data)
