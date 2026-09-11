import math
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import ProcurementCentre, CentreCounter, QueueEntry, Booking, Crop

router = APIRouter(prefix="/centres", tags=["Centre Discovery & Queue"])

class CentreDiscoveryItem(BaseModel):
    id: int
    name: str
    code: str
    centre_type: str
    latitude: float
    longitude: float
    address: Optional[str] = None
    district: str
    state: str
    distance_km: float
    current_queue_length: int
    active_counters: int
    estimated_wait_minutes: float
    ranking_score: float

class CentreQueueStatusResponse(BaseModel):
    centre_id: int
    centre_name: str
    active_counters: int
    waiting_count: int
    processing_count: int
    estimated_wait_minutes: float

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Earth radius in kilometers
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

@router.get("", response_model=List[CentreDiscoveryItem])
def get_ranked_centres(
    lat: Optional[float] = Query(None, description="Farmer latitude"),
    lng: Optional[float] = Query(None, description="Farmer longitude"),
    crop_type: Optional[str] = Query(None, description="Filter by crop name/type"),
    db: Session = Depends(get_db)
):
    centres = db.query(ProcurementCentre).filter(ProcurementCentre.is_active == True).all()

    # Default location to Mandya centre coordinates if not provided
    farmer_lat = lat if lat is not None else 12.5218
    farmer_lng = lng if lng is not None else 76.8951

    results = []
    for c in centres:
        # Distance
        dist_km = haversine_distance(farmer_lat, farmer_lng, c.latitude, c.longitude)

        # Active counters
        active_cnt = db.query(CentreCounter).filter(
            CentreCounter.centre_id == c.id,
            CentreCounter.is_active == True
        ).count()
        if active_cnt == 0:
            active_cnt = c.total_counters or 1

        # Current queue length (WAITING + PROCESSING)
        queue_len = db.query(QueueEntry).filter(
            QueueEntry.centre_id == c.id,
            QueueEntry.status.in_(["WAITING", "PROCESSING"])
        ).count()

        # Estimated wait time (minutes)
        est_wait = (queue_len * 15.0) / active_cnt

        # Multi-factor Ranking Function Score (Lower score is better)
        # Distance weight: 0.4, Wait time weight: 0.4, Queue length weight: 0.2
        ranking_score = (0.4 * dist_km) + (0.4 * est_wait) + (0.2 * queue_len)

        results.append(CentreDiscoveryItem(
            id=c.id,
            name=c.name,
            code=c.code,
            centre_type=c.centre_type,
            latitude=c.latitude,
            longitude=c.longitude,
            address=c.address,
            district=c.district,
            state=c.state,
            distance_km=round(dist_km, 2),
            current_queue_length=queue_len,
            active_counters=active_cnt,
            estimated_wait_minutes=round(est_wait, 1),
            ranking_score=round(ranking_score, 2)
        ))

    # Sort centres by ranking score ascending (best ranked first)
    results.sort(key=lambda x: x.ranking_score)
    return results

@router.get("/{centre_id}/queue", response_model=CentreQueueStatusResponse)
def get_centre_queue_status(centre_id: int, db: Session = Depends(get_db)):
    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement centre not found")

    waiting_cnt = db.query(QueueEntry).filter(
        QueueEntry.centre_id == centre_id,
        QueueEntry.status == "WAITING"
    ).count()

    processing_cnt = db.query(QueueEntry).filter(
        QueueEntry.centre_id == centre_id,
        QueueEntry.status == "PROCESSING"
    ).count()

    active_cnt = db.query(CentreCounter).filter(
        CentreCounter.centre_id == centre_id,
        CentreCounter.is_active == True
    ).count()
    if active_cnt == 0:
        active_cnt = centre.total_counters or 1

    est_wait = ((waiting_cnt + processing_cnt) * 15.0) / active_cnt

    return CentreQueueStatusResponse(
        centre_id=centre.id,
        centre_name=centre.name,
        active_counters=active_cnt,
        waiting_count=waiting_cnt,
        processing_count=processing_cnt,
        estimated_wait_minutes=round(est_wait, 1)
    )
