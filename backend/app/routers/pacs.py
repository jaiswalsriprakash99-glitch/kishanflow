import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import PACS, ProcurementCentre, ProcurementRecord, Booking, AppConfiguration, Farmer, Crop
from backend.app.routers.auth import RequireRole

router = APIRouter(prefix="/pacs", tags=["PACS Collection & Forwarding"])

class PACSCollectionRequest(BaseModel):
    pacs_id: int
    farmer_id: int
    crop_id: int
    quantity_quintals: float
    total_amount: float

class PACSForwardRequest(BaseModel):
    procurement_record_id: int
    destination_centre_id: int

class PACSProcurementResponse(BaseModel):
    id: int
    pacs_id: Optional[int] = None
    farmer_id: int
    centre_id: int
    crop_id: int
    quantity_quintals: float
    total_amount: float
    status: str
    is_forwarded: bool
    created_at: str

@router.post("/collection", response_model=PACSProcurementResponse)
def create_pacs_collection(
    request: PACSCollectionRequest,
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    pacs = db.query(PACS).filter(PACS.id == request.pacs_id).first()
    if not pacs:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="PACS not found")

    # Find matching PACS centre or default centre
    pacs_centre = db.query(ProcurementCentre).filter(ProcurementCentre.pacs_id == pacs.id).first()
    centre_id = pacs_centre.id if pacs_centre else 1

    # Check if forwarding required from app_configurations
    config = db.query(AppConfiguration).filter(AppConfiguration.key == "PACS_FORWARDING_REQUIRED").first()
    forwarding_required = (config.value.lower() == "true") if config else True

    initial_status = "COLLECTED_AT_PACS" if forwarding_required else "COMPLETED"

    # Create dummy booking if required for FK constraint
    booking = db.query(Booking).filter(Booking.farmer_id == request.farmer_id).first()
    booking_id = booking.id if booking else 1

    record = ProcurementRecord(
        booking_id=booking_id,
        farmer_id=request.farmer_id,
        centre_id=centre_id,
        crop_id=request.crop_id,
        quantity_quintals=request.quantity_quintals,
        total_amount=request.total_amount,
        status=initial_status,
        pacs_id=pacs.id,
        is_forwarded=False
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    return PACSProcurementResponse(
        id=record.id,
        pacs_id=record.pacs_id,
        farmer_id=record.farmer_id,
        centre_id=record.centre_id,
        crop_id=record.crop_id,
        quantity_quintals=record.quantity_quintals,
        total_amount=record.total_amount,
        status=record.status,
        is_forwarded=record.is_forwarded,
        created_at=record.created_at.isoformat()
    )

@router.get("/pending", response_model=List[PACSProcurementResponse])
def get_pending_pacs_collections(
    pacs_id: int = Query(...),
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    records = db.query(ProcurementRecord).filter(
        ProcurementRecord.pacs_id == pacs_id,
        ProcurementRecord.is_forwarded == False
    ).all()

    return [
        PACSProcurementResponse(
            id=r.id,
            pacs_id=r.pacs_id,
            farmer_id=r.farmer_id,
            centre_id=r.centre_id,
            crop_id=r.crop_id,
            quantity_quintals=r.quantity_quintals,
            total_amount=r.total_amount,
            status=r.status,
            is_forwarded=r.is_forwarded,
            created_at=r.created_at.isoformat()
        )
        for r in records
    ]

@router.post("/forward", response_model=PACSProcurementResponse)
def forward_pacs_collection(
    request: PACSForwardRequest,
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    record = db.query(ProcurementRecord).filter(ProcurementRecord.id == request.procurement_record_id).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement record not found")

    dest_centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == request.destination_centre_id).first()
    if not dest_centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Destination procurement centre not found")

    record.centre_id = dest_centre.id
    record.status = "FORWARDED_TO_CENTRE"
    record.is_forwarded = True

    db.commit()
    db.refresh(record)

    return PACSProcurementResponse(
        id=record.id,
        pacs_id=record.pacs_id,
        farmer_id=record.farmer_id,
        centre_id=record.centre_id,
        crop_id=record.crop_id,
        quantity_quintals=record.quantity_quintals,
        total_amount=record.total_amount,
        status=record.status,
        is_forwarded=record.is_forwarded,
        created_at=record.created_at.isoformat()
    )
