from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Booking, ProcurementRecord, QualityCheck, Weighment
from backend.app.routers.auth import RequireRole

router = APIRouter(prefix="/procurement", tags=["Procurement Lifecycle & Timeline"])

FORWARD_LIFECYCLE = [
    "REGISTERED",
    "SLOT_BOOKED",
    "ARRIVED",
    "IN_QUEUE",
    "VERIFICATION",
    "QUALITY_CHECK",
    "WEIGHING",
    "ACCEPTED",
    "PROCUREMENT_COMPLETED"
]

class StatusUpdateRequest(BaseModel):
    new_status: str
    rejection_reason: Optional[str] = None

class ProcurementStatusResponse(BaseModel):
    booking_id: int
    booking_reference: str
    current_status: str
    current_step_index: int
    total_steps: int
    is_completed: bool
    is_rejected: bool
    rejection_reason: Optional[str] = None
    timeline_steps: List[Dict[str, Any]]

@router.get("/{booking_id}", response_model=ProcurementStatusResponse)
def get_procurement_status(booking_id: int, db: Session = Depends(get_db)):
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    curr = booking.status
    is_rejected = (curr == "QUALITY_REJECTED")
    is_completed = (curr == "PROCUREMENT_COMPLETED")

    if curr in FORWARD_LIFECYCLE:
        step_idx = FORWARD_LIFECYCLE.index(curr)
    elif is_rejected:
        step_idx = FORWARD_LIFECYCLE.index("QUALITY_CHECK")
    else:
        step_idx = 0

    qc = db.query(QualityCheck).filter(QualityCheck.booking_id == booking_id).first()
    rejection_reason = qc.rejection_reason if (is_rejected and qc) else None

    timeline = []
    for idx, s in enumerate(FORWARD_LIFECYCLE):
        if is_rejected and s == "QUALITY_CHECK":
            timeline.append({"step_name": s, "status": "REJECTED", "index": idx})
        elif idx < step_idx:
            timeline.append({"step_name": s, "status": "COMPLETED", "index": idx})
        elif idx == step_idx:
            timeline.append({"step_name": s, "status": "IN_PROGRESS" if not is_completed else "COMPLETED", "index": idx})
        else:
            timeline.append({"step_name": s, "status": "PENDING", "index": idx})

    return ProcurementStatusResponse(
        booking_id=booking.id,
        booking_reference=booking.booking_reference,
        current_status=curr,
        current_step_index=step_idx,
        total_steps=len(FORWARD_LIFECYCLE),
        is_completed=is_completed,
        is_rejected=is_rejected,
        rejection_reason=rejection_reason,
        timeline_steps=timeline
    )

@router.post("/{booking_id}/update-status")
def update_procurement_status(
    booking_id: int,
    request: StatusUpdateRequest,
    payload: dict = Depends(RequireRole(["CENTRE_STAFF", "PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    booking = db.query(Booking).filter(Booking.id == booking_id).first()
    if not booking:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Booking not found")

    curr_status = booking.status
    new_status = request.new_status

    if new_status == "QUALITY_REJECTED":
        if not request.rejection_reason:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Rejection reason is mandatory when transitioning to QUALITY_REJECTED state."
            )
        booking.status = "QUALITY_REJECTED"
        qc = QualityCheck(
            booking_id=booking_id,
            moisture_content_percent=18.5,
            foreign_matter_percent=3.2,
            broken_grains_percent=5.0,
            passed=False,
            rejection_reason=request.rejection_reason
        )
        db.add(qc)
        db.commit()
        return {"status": "ok", "new_status": "QUALITY_REJECTED"}

    # Enforce forward-only transition rules
    if curr_status not in FORWARD_LIFECYCLE or new_status not in FORWARD_LIFECYCLE:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid status transition state")

    curr_idx = FORWARD_LIFECYCLE.index(curr_status)
    new_idx = FORWARD_LIFECYCLE.index(new_status)

    # Transition must move exactly forward (new_idx == curr_idx + 1)
    if new_idx != curr_idx + 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Out-of-order status transition attempt rejected: Cannot transition directly from '{curr_status}' to '{new_status}'."
        )

    booking.status = new_status
    db.commit()
    return {"status": "ok", "new_status": new_status}
