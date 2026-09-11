import uuid
import datetime
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Payment, Booking, Farmer
from backend.app.services.notifications import NotificationManager
from backend.app.routers.auth import RequireRole

router = APIRouter(prefix="/payment", tags=["Simulated Payment System"])

class PaymentResponse(BaseModel):
    id: int
    booking_id: int
    farmer_id: int
    amount: float
    payment_reference: str
    status: str
    is_simulated: bool
    initiated_at: str
    credited_at: Optional[str] = None

@router.get("/{booking_id}", response_model=PaymentResponse)
def get_payment_status(booking_id: int, db: Session = Depends(get_db)):
    payment = db.query(Payment).filter(Payment.booking_id == booking_id).first()
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    if not payment:
        # Create initial simulated payment record
        ref = f"SIM-DBT-{datetime.date.today().strftime('%Y%m')}-{uuid.uuid4().hex[:6].upper()}"
        calc_amount = round(booking.estimated_quantity_quintals * 2183.0, 2)
        payment = Payment(
            booking_id=booking_id,
            farmer_id=booking.farmer_id,
            amount=calc_amount,
            payment_reference=ref,
            status="INITIATED",
            is_simulated=True,
            initiated_at=datetime.datetime.utcnow()
        )
        db.add(payment)
        db.commit()
        db.refresh(payment)

    return PaymentResponse(
        id=payment.id,
        booking_id=payment.booking_id,
        farmer_id=payment.farmer_id,
        amount=payment.amount,
        payment_reference=payment.payment_reference,
        status=payment.status,
        is_simulated=True, # MANDATORY FLAG
        initiated_at=payment.initiated_at.isoformat(),
        credited_at=payment.credited_at.isoformat() if payment.credited_at else None
    )

@router.post("/{booking_id}/trigger-simulated-payment", response_model=PaymentResponse)
def progress_simulated_payment(
    booking_id: int,
    payload: dict = Depends(RequireRole(["FARMER", "CENTRE_STAFF", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    payment_res = get_payment_status(booking_id, db)
    payment = db.query(Payment).filter(Payment.id == payment_res.id).first()
    farmer = db.query(Farmer).filter(Farmer.id == payment.farmer_id).first()

    # Progress state: INITIATED -> PROCESSING -> CREDITED
    now = datetime.datetime.utcnow()
    if payment.status == "INITIATED":
        payment.status = "PROCESSING"
    elif payment.status == "PROCESSING":
        payment.status = "CREDITED"
        payment.credited_at = now

    db.commit()
    db.refresh(payment)

    # Trigger Payment Notification via Prompt 13 Notification pipeline
    if farmer:
        NotificationManager.dispatch_event(
            event_type="PAYMENT_STATUS_CHANGED",
            farmer_id=farmer.id,
            phone_number=farmer.phone_number,
            title="Simulated Payment Status Update",
            message=f"Your DBT payment of ₹{payment.amount} status is now {payment.status} (Ref: {payment.payment_reference}).",
            db=db
        )

    return PaymentResponse(
        id=payment.id,
        booking_id=payment.booking_id,
        farmer_id=payment.farmer_id,
        amount=payment.amount,
        payment_reference=payment.payment_reference,
        status=payment.status,
        is_simulated=True,
        initiated_at=payment.initiated_at.isoformat(),
        credited_at=payment.credited_at.isoformat() if payment.credited_at else None
    )
