import asyncio
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import QueueEntry, Booking
from backend.app.services.queue_engine import QueueEngine
from backend.app.routers.auth import RequireRole
from backend.app.ws.connection_manager import manager

router = APIRouter(tags=["Queue Engine"])

class QueueStatusResponse(BaseModel):
    booking_id: int
    booking_reference: str
    centre_id: int
    position: int
    status: str
    counter_id: Optional[int] = None
    actual_wait_minutes: Optional[float] = None
    farmers_ahead: int

class StaffActionRequest(BaseModel):
    booking_id: int
    counter_id: Optional[int] = 1

def broadcast_update_safely(centre_id: int, event_type: str, booking_id: int, new_status: str):
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(manager.broadcast_queue_update(
            centre_id=centre_id,
            message_data={
                "event_type": "queue_update",
                "action": event_type,
                "booking_id": booking_id,
                "new_status": new_status,
                "timestamp": asyncio.get_event_loop().time()
            }
        ))
    except RuntimeError:
        pass # Handle synchronous test runners gracefully

@router.get("/queue/{booking_id}", response_model=QueueStatusResponse)
def get_queue_status(booking_id: int, db: Session = Depends(get_db)):
    q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    if not q_entry:
        return QueueStatusResponse(
            booking_id=booking.id,
            booking_reference=booking.booking_reference,
            centre_id=booking.centre_id,
            position=0,
            status="NOT_ARRIVED",
            farmers_ahead=0
        )

    farmers_ahead = max(0, q_entry.position - 1) if q_entry.status == "WAITING" else 0

    return QueueStatusResponse(
        booking_id=booking.id,
        booking_reference=booking.booking_reference,
        centre_id=booking.centre_id,
        position=q_entry.position,
        status=q_entry.status,
        counter_id=q_entry.counter_id,
        actual_wait_minutes=q_entry.actual_wait_minutes,
        farmers_ahead=farmers_ahead
    )

@router.post("/queue/{booking_id}/arrive", response_model=QueueStatusResponse)
def arrive_farmer_at_centre(
    booking_id: int,
    payload: dict = Depends(RequireRole(["FARMER", "CENTRE_STAFF"])),
    db: Session = Depends(get_db)
):
    try:
        q_entry = QueueEngine.arrive_farmer(db, booking_id)
        db.commit()
        broadcast_update_safely(q_entry.centre_id, "ARRIVED", booking_id, q_entry.status)
        return get_queue_status(booking_id, db)
    except ValueError as ve:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))

@router.post("/staff/queue/start")
def staff_start_queue(
    request: StaffActionRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    try:
        q_entry = QueueEngine.start_service(db, request.booking_id, request.counter_id or 1, staff_id=staff_id)
        db.commit()
        broadcast_update_safely(q_entry.centre_id, "START", request.booking_id, q_entry.status)
        return {"status": "ok", "message": f"Started processing booking {request.booking_id}"}
    except ValueError as ve:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))

@router.post("/staff/queue/complete")
def staff_complete_queue(
    request: StaffActionRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    try:
        q_entry = QueueEngine.complete_service(db, request.booking_id, staff_id=staff_id)
        db.commit()
        broadcast_update_safely(q_entry.centre_id, "COMPLETED", request.booking_id, q_entry.status)
        return {"status": "ok", "message": f"Completed service for booking {request.booking_id}"}
    except ValueError as ve:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))

@router.post("/staff/queue/skip")
def staff_skip_queue(
    request: StaffActionRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    try:
        q_entry = QueueEngine.skip_farmer(db, request.booking_id, staff_id=staff_id)
        db.commit()
        broadcast_update_safely(q_entry.centre_id, "SKIPPED", request.booking_id, q_entry.status)
        return {"status": "ok", "message": f"Skipped booking {request.booking_id}"}
    except ValueError as ve:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))

@router.post("/staff/queue/no-show")
def staff_no_show_queue(
    request: StaffActionRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    try:
        q_entry = QueueEngine.no_show_farmer(db, request.booking_id, staff_id=staff_id)
        db.commit()
        broadcast_update_safely(q_entry.centre_id, "NO_SHOW", request.booking_id, q_entry.status)
        return {"status": "ok", "message": f"Marked booking {request.booking_id} as NO_SHOW"}
    except ValueError as ve:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(ve))
