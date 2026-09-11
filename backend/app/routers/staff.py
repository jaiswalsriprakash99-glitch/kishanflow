import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import ProcurementCentre, CentreCounter, QueueEntry, Booking, StaffUser
from backend.app.routers.auth import RequireRole

router = APIRouter(prefix="/staff", tags=["Staff Operations"])

class PauseCentreRequest(BaseModel):
    centre_id: int
    is_paused: bool
    delay_reason: str # Mandatory delay-reason field!

class CounterToggleRequest(BaseModel):
    counter_id: int
    is_active: bool

class StaffDashboardResponse(BaseModel):
    centre_id: int
    centre_name: str
    total_farmers_today: int
    completed_count: int
    waiting_count: int
    processing_count: int
    active_counters_count: int
    is_paused: bool
    delay_reason: Optional[str] = None

@router.get("/dashboard/{centre_id}", response_model=StaffDashboardResponse)
def get_staff_dashboard_summary(
    centre_id: int,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement Centre not found")

    total_today = db.query(Booking).filter(Booking.centre_id == centre_id).count()
    completed_cnt = db.query(QueueEntry).filter(QueueEntry.centre_id == centre_id, QueueEntry.status == "COMPLETED").count()
    waiting_cnt = db.query(QueueEntry).filter(QueueEntry.centre_id == centre_id, QueueEntry.status == "WAITING").count()
    processing_cnt = db.query(QueueEntry).filter(QueueEntry.centre_id == centre_id, QueueEntry.status == "PROCESSING").count()
    active_cnt = db.query(CentreCounter).filter(CentreCounter.centre_id == centre_id, CentreCounter.is_active == True).count()

    return StaffDashboardResponse(
        centre_id=centre.id,
        centre_name=centre.name,
        total_farmers_today=total_today,
        completed_count=completed_cnt,
        waiting_count=waiting_cnt,
        processing_count=processing_cnt,
        active_counters_count=active_cnt,
        is_paused=not centre.is_active,
        delay_reason=None
    )

@router.post("/centre/pause")
def pause_resume_centre(
    request: PauseCentreRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    if request.is_paused and not request.delay_reason.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Delay reason is mandatory when pausing procurement centre operations."
        )

    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == request.centre_id).first()
    if not centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement Centre not found")

    centre.is_active = not request.is_paused
    db.commit()

    return {
        "status": "ok",
        "centre_id": centre.id,
        "is_paused": request.is_paused,
        "delay_reason": request.delay_reason.strip()
    }

@router.post("/counter/toggle")
def toggle_counter_status(
    request: CounterToggleRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    counter = db.query(CentreCounter).filter(CentreCounter.id == request.counter_id).first()
    if not counter:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Counter not found")

    counter.is_active = request.is_active
    db.commit()

    return {
        "status": "ok",
        "counter_id": counter.id,
        "is_active": counter.is_active
    }
