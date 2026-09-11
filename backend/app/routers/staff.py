import datetime
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import (
    ProcurementCentre, CentreCounter, QueueEntry, Booking, StaffUser,
    Farmer, Crop, Slot, QualityCheck, Weighment, ProcurementRecord, AIPrediction
)
from backend.app.services.queue_engine import QueueEngine
from backend.app.routers.auth import RequireRole
from backend.app.routers.queue import broadcast_update_safely

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
    current_token: Optional[str] = None
    next_token: Optional[str] = None
    average_wait_minutes: float = 15.0

class ScheduleBookingItem(BaseModel):
    booking_id: int
    booking_reference: str
    token_number: int
    farmer_name: str
    farmer_phone: str
    crop_name: str
    estimated_quantity_quintals: float
    slot_date: str
    slot_time: str
    arrival_status: str
    queue_status: str
    procurement_status: str
    counter_id: Optional[int] = None

class QualityCheckRequest(BaseModel):
    moisture_content_percent: float
    foreign_matter_percent: float
    broken_grains_percent: float
    grade: str = "Grade A"
    passed: bool
    rejection_reason: Optional[str] = None

class WeighmentRequest(BaseModel):
    gross_weight_kg: float
    tare_weight_kg: float
    bags_count: int

class CallNextRequest(BaseModel):
    centre_id: int
    counter_id: int = 1

class CompleteProcurementRequest(BaseModel):
    booking_id: int

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

    current_processing = db.query(QueueEntry).filter(
        QueueEntry.centre_id == centre_id,
        QueueEntry.status == "PROCESSING"
    ).first()

    next_waiting = db.query(QueueEntry).filter(
        QueueEntry.centre_id == centre_id,
        QueueEntry.status == "WAITING"
    ).order_by(QueueEntry.position.asc()).first()

    current_token = f"#{current_processing.booking.queue_number}" if current_processing and current_processing.booking else "None"
    next_token = f"#{next_waiting.booking.queue_number}" if next_waiting and next_waiting.booking else "None"

    return StaffDashboardResponse(
        centre_id=centre.id,
        centre_name=centre.name,
        total_farmers_today=total_today,
        completed_count=completed_cnt,
        waiting_count=waiting_cnt,
        processing_count=processing_cnt,
        active_counters_count=active_cnt,
        is_paused=not centre.is_active,
        delay_reason=None,
        current_token=current_token,
        next_token=next_token,
        average_wait_minutes=15.0
    )

@router.get("/centre/{centre_id}/schedule", response_model=List[ScheduleBookingItem])
def get_centre_schedule(
    centre_id: int,
    status_filter: Optional[str] = Query(None, description="Filter by queue/arrival status"),
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    query = db.query(Booking).filter(Booking.centre_id == centre_id)
    bookings = query.all()

    items = []
    for b in bookings:
        farmer = db.query(Farmer).filter(Farmer.id == b.farmer_id).first()
        crop = db.query(Crop).filter(Crop.id == b.crop_id).first()
        slot = db.query(Slot).filter(Slot.id == b.slot_id).first()
        q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == b.id).first()

        arr_status = "ARRIVED" if q_entry else "NOT_ARRIVED"
        q_status = q_entry.status if q_entry else "NOT_ARRIVED"
        counter_id = q_entry.counter_id if q_entry else None

        if status_filter and status_filter.upper() != "ALL":
            sf = status_filter.upper()
            if sf == "WAITING" and q_status != "WAITING":
                continue
            elif sf == "ARRIVED" and arr_status != "ARRIVED":
                continue
            elif sf == "PROCESSING" and q_status != "PROCESSING":
                continue
            elif sf == "COMPLETED" and q_status != "COMPLETED":
                continue
            elif sf == "NO_SHOW" and q_status != "NO_SHOW":
                continue

        items.append(ScheduleBookingItem(
            booking_id=b.id,
            booking_reference=b.booking_reference,
            token_number=b.queue_number,
            farmer_name=farmer.full_name if farmer else "Unknown Farmer",
            farmer_phone=farmer.phone_number if farmer else "",
            crop_name=crop.name if crop else "Crop",
            estimated_quantity_quintals=b.estimated_quantity_quintals,
            slot_date=slot.slot_date if slot else "Today",
            slot_time=f"{slot.start_time}-{slot.end_time}" if slot else "09:00-13:00",
            arrival_status=arr_status,
            queue_status=q_status,
            procurement_status=b.status,
            counter_id=counter_id
        ))

    items.sort(key=lambda x: x.token_number)
    return items

@router.get("/centre/{centre_id}/counters")
def get_centre_counters(
    centre_id: int,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    counters = db.query(CentreCounter).filter(CentreCounter.centre_id == centre_id).all()
    results = []
    for c in counters:
        current_entry = db.query(QueueEntry).filter(
            QueueEntry.centre_id == centre_id,
            QueueEntry.counter_id == c.id,
            QueueEntry.status == "PROCESSING"
        ).first()
        
        current_farmer = None
        if current_entry and current_entry.booking:
            farmer = db.query(Farmer).filter(Farmer.id == current_entry.booking.farmer_id).first()
            current_farmer = farmer.full_name if farmer else None

        results.append({
            "id": c.id,
            "counter_number": c.counter_number,
            "counter_name": c.counter_name,
            "is_active": c.is_active,
            "current_token": f"#{current_entry.booking.queue_number}" if current_entry and current_entry.booking else None,
            "current_farmer": current_farmer,
            "processing_state": current_entry.status if current_entry else "IDLE"
        })
    return results

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

@router.post("/queue/call-next")
def call_next_farmer(
    request: CallNextRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    next_entry = db.query(QueueEntry).filter(
        QueueEntry.centre_id == request.centre_id,
        QueueEntry.status == "WAITING"
    ).order_by(QueueEntry.position.asc()).with_for_update().first()

    if not next_entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No waiting farmers in queue for this centre.")

    try:
        q_entry = QueueEngine.start_service(db, next_entry.booking_id, request.counter_id, staff_id=staff_id)
        db.commit()
        broadcast_update_safely(request.centre_id, "START", next_entry.booking_id, q_entry.status)
        
        booking = db.query(Booking).filter(Booking.id == next_entry.booking_id).first()
        farmer = db.query(Farmer).filter(Farmer.id == booking.farmer_id).first() if booking else None
        
        return {
            "status": "ok",
            "booking_id": next_entry.booking_id,
            "token_number": booking.queue_number if booking else 0,
            "farmer_name": farmer.full_name if farmer else "Farmer",
            "counter_id": request.counter_id,
            "message": f"Called next farmer #{booking.queue_number if booking else 0} to Counter {request.counter_id}"
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

@router.post("/procurement/{booking_id}/verify")
def verify_farmer_ticket(
    booking_id: int,
    verified: bool = Query(True),
    failure_reason: Optional[str] = Query(None),
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    if verified:
        booking.status = "VERIFICATION"
    else:
        booking.status = "VERIFICATION_FAILED"

    db.commit()
    broadcast_update_safely(booking.centre_id, "VERIFICATION", booking_id, booking.status)
    return {"status": "ok", "booking_id": booking_id, "verified": verified, "current_status": booking.status}

@router.post("/procurement/{booking_id}/quality-check")
def submit_quality_check(
    booking_id: int,
    request: QualityCheckRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    qc = QualityCheck(
        booking_id=booking_id,
        inspector_id=staff_id,
        moisture_content_percent=request.moisture_content_percent,
        foreign_matter_percent=request.foreign_matter_percent,
        broken_grains_percent=request.broken_grains_percent,
        grade=request.grade,
        passed=request.passed,
        rejection_reason=request.rejection_reason if not request.passed else None
    )
    db.add(qc)

    if request.passed:
        booking.status = "WEIGHING"
    else:
        if not request.rejection_reason:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Rejection reason mandatory when rejecting quality check")
        booking.status = "QUALITY_REJECTED"

    db.commit()
    broadcast_update_safely(booking.centre_id, "QUALITY_CHECK", booking_id, booking.status)
    return {
        "status": "ok",
        "booking_id": booking_id,
        "passed": request.passed,
        "new_status": booking.status,
        "rejection_reason": request.rejection_reason
    }

@router.post("/procurement/{booking_id}/weighment")
def submit_weighment(
    booking_id: int,
    request: WeighmentRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    net_weight_kg = request.gross_weight_kg - request.tare_weight_kg
    if net_weight_kg <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Net weight must be positive.")

    w = Weighment(
        booking_id=booking_id,
        weighbridge_operator_id=staff_id,
        gross_weight_kg=request.gross_weight_kg,
        tare_weight_kg=request.tare_weight_kg,
        net_weight_kg=net_weight_kg,
        bags_count=request.bags_count
    )
    db.add(w)

    booking.status = "ACCEPTED"
    db.commit()

    broadcast_update_safely(booking.centre_id, "WEIGHING", booking_id, booking.status)
    return {
        "status": "ok",
        "booking_id": booking_id,
        "net_weight_kg": net_weight_kg,
        "net_quintals": round(net_weight_kg / 100.0, 2),
        "new_status": booking.status
    }

@router.post("/procurement/{booking_id}/complete")
def complete_procurement_flow(
    booking_id: int,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN"])),
    db: Session = Depends(get_db)
):
    staff_id = int(payload.get("sub", 0)) if "sub" in payload and str(payload["sub"]).isdigit() else None
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    weighment = db.query(Weighment).filter(Weighment.booking_id == booking_id).order_by(Weighment.id.desc()).first()
    quantity_quintals = round(weighment.net_weight_kg / 100.0, 2) if weighment else booking.estimated_quantity_quintals

    crop = db.query(Crop).filter(Crop.id == booking.crop_id).first()
    msp = crop.msp_per_quintal if crop else 2183.0
    total_amount = round(quantity_quintals * msp, 2)

    proc_record = db.query(ProcurementRecord).filter(ProcurementRecord.booking_id == booking_id).first()
    if not proc_record:
        proc_record = ProcurementRecord(
            booking_id=booking_id,
            farmer_id=booking.farmer_id,
            centre_id=booking.centre_id,
            crop_id=booking.crop_id,
            quantity_quintals=quantity_quintals,
            total_amount=total_amount,
            status="ACCEPTED"
        )
        db.add(proc_record)

    booking.status = "PROCUREMENT_COMPLETED"
    
    q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
    if q_entry:
        QueueEngine.complete_service(db, booking_id, staff_id=staff_id)

    db.commit()
    broadcast_update_safely(booking.centre_id, "PROCUREMENT_COMPLETED", booking_id, "PROCUREMENT_COMPLETED")

    return {
        "status": "ok",
        "booking_id": booking_id,
        "quantity_quintals": quantity_quintals,
        "total_amount": total_amount,
        "new_status": "PROCUREMENT_COMPLETED"
    }

@router.get("/summary/{centre_id}")
def get_daily_summary(
    centre_id: int,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Centre not found")

    completed_records = db.query(ProcurementRecord).filter(ProcurementRecord.centre_id == centre_id).all()
    total_farmers = len(completed_records)
    total_quintals = sum(r.quantity_quintals for r in completed_records)
    total_payout = sum(r.total_amount for r in completed_records)

    rejected_count = db.query(Booking).filter(Booking.centre_id == centre_id, Booking.status == "QUALITY_REJECTED").count()

    return {
        "centre_id": centre_id,
        "centre_name": centre.name,
        "completed_farmers": total_farmers,
        "total_procured_quintals": round(total_quintals, 2),
        "total_payout_amount": round(total_payout, 2),
        "rejected_batches_count": rejected_count
    }
