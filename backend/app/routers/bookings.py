import uuid
import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Slot, Booking, ProcurementCentre, Crop, Farmer
from backend.app.routers.auth import RequireRole

router = APIRouter(tags=["Slot Booking"])

class SlotResponse(BaseModel):
    id: int
    centre_id: int
    crop_id: int
    slot_date: str
    start_time: str
    end_time: str
    capacity: int
    booked_count: int
    available_seats: int
    is_active: bool

class CreateBookingRequest(BaseModel):
    slot_id: int
    crop_id: int
    estimated_quantity_quintals: float
    idempotency_key: Optional[str] = None

class RescheduleBookingRequest(BaseModel):
    new_slot_id: int

class BookingResponse(BaseModel):
    id: int
    booking_reference: str
    farmer_id: int
    slot_id: int
    centre_id: int
    crop_id: int
    estimated_quantity_quintals: float
    queue_number: int
    status: str
    qr_code_token: str
    created_at: str

@router.get("/centres/{centre_id}/slots", response_model=List[SlotResponse])
def get_centre_slots(
    centre_id: int,
    crop_id: Optional[int] = Query(None),
    date: Optional[str] = Query(None),
    db: Session = Depends(get_db)
):
    query = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.is_active == True)
    if crop_id:
        query = query.filter(Slot.crop_id == crop_id)
    if date:
        query = query.filter(Slot.slot_date == date)

    slots = query.order_by(Slot.slot_date, Slot.start_time).all()
    results = []
    for s in slots:
        avail = max(0, s.capacity - s.booked_count)
        results.append(SlotResponse(
            id=s.id,
            centre_id=s.centre_id,
            crop_id=s.crop_id,
            slot_date=s.slot_date,
            start_time=s.start_time,
            end_time=s.end_time,
            capacity=s.capacity,
            booked_count=s.booked_count,
            available_seats=avail,
            is_active=s.is_active
        ))
    return results

@router.post("/bookings", response_model=BookingResponse)
def create_booking(
    request: CreateBookingRequest,
    payload: dict = Depends(RequireRole(["FARMER"])),
    db: Session = Depends(get_db)
):
    farmer_id = int(payload["sub"])

    if request.estimated_quantity_quintals <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Estimated quantity must be greater than 0")

    # Transaction with Row Locking (SELECT ... FOR UPDATE on PostgreSQL / locked session on SQLite)
    try:
        query = db.query(Slot).filter(Slot.id == request.slot_id)
        if db.bind and db.bind.dialect.name != "sqlite":
            query = query.with_for_update()

        slot = query.first()
        if not slot:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Target slot not found")

        if slot.booked_count >= slot.capacity:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Slot capacity reached. No seats available."
            )

        # Check unique constraint on (farmer_id, slot_id)
        existing = db.query(Booking).filter(
            Booking.farmer_id == farmer_id,
            Booking.slot_id == slot.id,
            Booking.status != "CANCELLED"
        ).first()
        if existing:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Farmer already has an active booking for this slot."
            )

        # Increment booked_count safely within locked transaction
        slot.booked_count += 1

        # Calculate sequential queue_number for this centre on this slot_date
        centre_date_count = db.query(Booking).filter(
            Booking.centre_id == slot.centre_id,
            Booking.slot_id == slot.id
        ).count()
        queue_num = centre_date_count + 1

        booking_ref = f"BK-{slot.centre_id}-{datetime.date.today().strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"
        qr_token = f"QR-{uuid.uuid4().hex[:12].upper()}"

        booking = Booking(
            booking_reference=booking_ref,
            farmer_id=farmer_id,
            slot_id=slot.id,
            centre_id=slot.centre_id,
            crop_id=request.crop_id,
            estimated_quantity_quintals=request.estimated_quantity_quintals,
            queue_number=queue_num,
            status="SLOT_BOOKED",
            qr_code_token=qr_token
        )
        db.add(booking)
        db.commit()
        db.refresh(booking)

        return BookingResponse(
            id=booking.id,
            booking_reference=booking.booking_reference,
            farmer_id=booking.farmer_id,
            slot_id=booking.slot_id,
            centre_id=booking.centre_id,
            crop_id=booking.crop_id,
            estimated_quantity_quintals=booking.estimated_quantity_quintals,
            queue_number=booking.queue_number,
            status=booking.status,
            qr_code_token=booking.qr_code_token,
            created_at=booking.created_at.isoformat()
        )
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))

@router.post("/bookings/{booking_id}/cancel")
def cancel_booking(
    booking_id: int,
    payload: dict = Depends(RequireRole(["FARMER"])),
    db: Session = Depends(get_db)
):
    farmer_id = int(payload["sub"])
    query = db.query(Booking).filter(Booking.id == booking_id, Booking.farmer_id == farmer_id)
    if db.bind and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()
    booking = query.first()

    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    if booking.status == "CANCELLED":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Booking is already cancelled")

    booking.status = "CANCELLED"

    slot_query = db.query(Slot).filter(Slot.id == booking.slot_id)
    if db.bind and db.bind.dialect.name != "sqlite":
        slot_query = slot_query.with_for_update()
    slot = slot_query.first()

    if slot and slot.booked_count > 0:
        slot.booked_count -= 1

    db.commit()
    return {"status": "ok", "message": "Booking cancelled successfully"}

@router.post("/bookings/{booking_id}/reschedule", response_model=BookingResponse)
def reschedule_booking(
    booking_id: int,
    request: RescheduleBookingRequest,
    payload: dict = Depends(RequireRole(["FARMER"])),
    db: Session = Depends(get_db)
):
    farmer_id = int(payload["sub"])
    query = db.query(Booking).filter(Booking.id == booking_id, Booking.farmer_id == farmer_id)
    if db.bind and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()
    booking = query.first()

    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    old_slot_q = db.query(Slot).filter(Slot.id == booking.slot_id)
    new_slot_q = db.query(Slot).filter(Slot.id == request.new_slot_id)
    if db.bind and db.bind.dialect.name != "sqlite":
        old_slot_q = old_slot_q.with_for_update()
        new_slot_q = new_slot_q.with_for_update()

    old_slot = old_slot_q.first()
    new_slot = new_slot_q.first()

    if not new_slot:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="New slot not found")

    if new_slot.booked_count >= new_slot.capacity:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="New slot is fully booked")

    if old_slot and old_slot.booked_count > 0:
        old_slot.booked_count -= 1

    new_slot.booked_count += 1
    booking.slot_id = new_slot.id
    booking.centre_id = new_slot.centre_id
    booking.crop_id = new_slot.crop_id
    booking.status = "SLOT_BOOKED"

    db.commit()
    db.refresh(booking)

    return BookingResponse(
        id=booking.id,
        booking_reference=booking.booking_reference,
        farmer_id=booking.farmer_id,
        slot_id=booking.slot_id,
        centre_id=booking.centre_id,
        crop_id=booking.crop_id,
        estimated_quantity_quintals=booking.estimated_quantity_quintals,
        queue_number=booking.queue_number,
        status=booking.status,
        qr_code_token=booking.qr_code_token,
        created_at=booking.created_at.isoformat()
    )
