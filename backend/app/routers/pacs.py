import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy import func
from backend.app.database import get_db
from backend.app.models import PACS, ProcurementCentre, ProcurementRecord, Booking, AppConfiguration, Farmer, Crop, Payment, StaffUser
from backend.app.routers.auth import RequireRole

router = APIRouter(prefix="/pacs", tags=["PACS Collection & Forwarding"])

def verify_pacs_ownership(payload: dict, target_pacs_id: int):
    user_role = payload.get("role")
    if user_role == "PACS_OPERATOR":
        user_pacs_id = payload.get("pacs_id")
        if user_pacs_id is not None and user_pacs_id != target_pacs_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Forbidden: You are not authorized to access or modify data for another PACS."
            )

class PACSCollectionRequest(BaseModel):
    pacs_id: int
    farmer_id: int
    crop_id: int
    quantity_quintals: float
    total_amount: Optional[float] = None
    declared_quantity_quintals: Optional[float] = None

class PACSForwardRequest(BaseModel):
    procurement_record_id: int
    destination_centre_id: int

class PACSProcurementResponse(BaseModel):
    id: int
    pacs_id: Optional[int] = None
    pacs_name: Optional[str] = None
    farmer_id: int
    farmer_name: Optional[str] = None
    farmer_phone: Optional[str] = None
    centre_id: int
    centre_name: Optional[str] = None
    crop_id: int
    crop_name: Optional[str] = None
    quantity_quintals: float
    total_amount: float
    status: str
    is_forwarded: bool
    created_at: str

class PACSDashboardSummaryResponse(BaseModel):
    pacs_id: int
    pacs_name: str
    pacs_code: str
    district: str
    state: str
    operational_status: str
    registered_farmers_count: int
    today_collections_count: int
    pending_collections_count: int
    collected_quantity_quintals: float
    pending_forwarding_count: int
    dispatched_quantity_quintals: float
    received_quantity_quintals: float
    accepted_quantity_quintals: float
    rejected_count: int
    total_amount_rupees: float
    simulated_payment_count: int

class FarmerSearchResult(BaseModel):
    id: int
    full_name: str
    phone_number: str
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None

class DestinationCentreItem(BaseModel):
    id: int
    name: str
    code: str
    district: str
    centre_type: str

class PACSPaymentResponse(BaseModel):
    payment_id: Optional[int] = None
    procurement_record_id: int
    farmer_name: str
    farmer_phone: str
    crop_name: str
    quantity_quintals: float
    amount: float
    payment_reference: Optional[str] = None
    status: str
    is_simulated: bool
    created_at: str

@router.get("/dashboard-summary", response_model=PACSDashboardSummaryResponse)
def get_pacs_dashboard_summary(
    pacs_id: int = Query(...),
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    verify_pacs_ownership(payload, pacs_id)
    pacs = db.query(PACS).filter(PACS.id == pacs_id).first()
    if not pacs:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="PACS not found")

    today_start = datetime.datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)

    # Aggregations
    farmers_count = db.query(Farmer).count()
    today_collections = db.query(ProcurementRecord).filter(
        ProcurementRecord.pacs_id == pacs_id,
        ProcurementRecord.created_at >= today_start
    ).count()

    pending_records = db.query(ProcurementRecord).filter(
        ProcurementRecord.pacs_id == pacs_id,
        ProcurementRecord.is_forwarded == False
    ).all()
    pending_collections_count = len(pending_records)

    all_pacs_records = db.query(ProcurementRecord).filter(ProcurementRecord.pacs_id == pacs_id).all()
    total_collected_qty = sum(r.quantity_quintals for r in all_pacs_records)
    total_dispatched_qty = sum(r.quantity_quintals for r in all_pacs_records if r.is_forwarded)
    total_amount = sum(r.total_amount for r in all_pacs_records)

    received_count = sum(1 for r in all_pacs_records if r.status in ["FORWARDED_TO_CENTRE", "RECEIVED_AT_CENTRE", "ACCEPTED", "COMPLETED"])
    accepted_qty = sum(r.quantity_quintals for r in all_pacs_records if r.status in ["ACCEPTED", "COMPLETED"])
    rejected_count = sum(1 for r in all_pacs_records if r.status == "REJECTED")

    return PACSDashboardSummaryResponse(
        pacs_id=pacs.id,
        pacs_name=pacs.name,
        pacs_code=pacs.code,
        district=pacs.district,
        state=pacs.state,
        operational_status="ACTIVE",
        registered_farmers_count=farmers_count,
        today_collections_count=today_collections,
        pending_collections_count=pending_collections_count,
        collected_quantity_quintals=round(total_collected_qty, 2),
        pending_forwarding_count=pending_collections_count,
        dispatched_quantity_quintals=round(total_dispatched_qty, 2),
        received_quantity_quintals=round(total_dispatched_qty, 2),
        accepted_quantity_quintals=round(accepted_qty, 2),
        rejected_count=rejected_count,
        total_amount_rupees=round(total_amount, 2),
        simulated_payment_count=len(all_pacs_records)
    )

@router.get("/farmers/search", response_model=List[FarmerSearchResult])
def search_farmers_for_pacs(
    query: str = Query("", description="Search term for farmer phone, name, or ID"),
    pacs_id: int = Query(...),
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    verify_pacs_ownership(payload, pacs_id)
    q = query.strip()
    farmers_query = db.query(Farmer)
    if q:
        farmers_query = farmers_query.filter(
            (Farmer.phone_number.ilike(f"%{q}%")) |
            (Farmer.full_name.ilike(f"%{q}%"))
        )
    farmers = farmers_query.limit(20).all()

    results = []
    for f in farmers:
        prof = f.profile
        results.append(FarmerSearchResult(
            id=f.id,
            full_name=f.full_name,
            phone_number=f.phone_number,
            village=prof.village if prof else None,
            district=prof.district if prof else None,
            state=prof.state if prof else None
        ))
    return results

@router.get("/destination-centres", response_model=List[DestinationCentreItem])
def get_destination_centres(
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    centres = db.query(ProcurementCentre).filter(
        ProcurementCentre.is_active == True,
        ProcurementCentre.centre_type != "PACS"
    ).all()
    return [
        DestinationCentreItem(
            id=c.id,
            name=c.name,
            code=c.code,
            district=c.district,
            centre_type=c.centre_type
        )
        for c in centres
    ]

@router.post("/collection", response_model=PACSProcurementResponse)
def create_pacs_collection(
    request: PACSCollectionRequest,
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    verify_pacs_ownership(payload, request.pacs_id)

    if request.quantity_quintals <= 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid quantity: Collection quantity must be greater than zero."
        )

    pacs = db.query(PACS).filter(PACS.id == request.pacs_id).first()
    if not pacs:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="PACS not found")

    farmer = db.query(Farmer).filter(Farmer.id == request.farmer_id).first()
    if not farmer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Farmer not found")

    crop = db.query(Crop).filter(Crop.id == request.crop_id).first()
    if not crop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Crop not found")

    # Prevent duplicate collection submission for same farmer + crop today
    today_start = datetime.datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    existing_today = db.query(ProcurementRecord).filter(
        ProcurementRecord.pacs_id == request.pacs_id,
        ProcurementRecord.farmer_id == request.farmer_id,
        ProcurementRecord.crop_id == request.crop_id,
        ProcurementRecord.created_at >= today_start
    ).first()

    if existing_today:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Duplicate collection attempt: A collection record for {farmer.full_name} and {crop.name} already exists for today."
        )

    pacs_centre = db.query(ProcurementCentre).filter(ProcurementCentre.pacs_id == pacs.id).first()
    centre_id = pacs_centre.id if pacs_centre else 1

    total_amt = request.total_amount
    if not total_amt or total_amt <= 0:
        total_amt = round(request.quantity_quintals * crop.msp_per_quintal, 2)

    booking = db.query(Booking).filter(Booking.farmer_id == request.farmer_id).first()
    booking_id = booking.id if booking else None

    record = ProcurementRecord(
        booking_id=booking_id,
        farmer_id=request.farmer_id,
        centre_id=centre_id,
        crop_id=request.crop_id,
        quantity_quintals=request.quantity_quintals,
        total_amount=total_amt,
        status="COLLECTED_AT_PACS",
        pacs_id=pacs.id,
        is_forwarded=False
    )
    db.add(record)
    db.commit()
    db.refresh(record)

    centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == record.centre_id).first()

    return PACSProcurementResponse(
        id=record.id,
        pacs_id=record.pacs_id,
        pacs_name=pacs.name,
        farmer_id=record.farmer_id,
        farmer_name=farmer.full_name,
        farmer_phone=farmer.phone_number,
        centre_id=record.centre_id,
        centre_name=centre.name if centre else "Default Centre",
        crop_id=record.crop_id,
        crop_name=crop.name,
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
    verify_pacs_ownership(payload, pacs_id)
    records = db.query(ProcurementRecord).filter(
        ProcurementRecord.pacs_id == pacs_id,
        ProcurementRecord.is_forwarded == False
    ).order_by(ProcurementRecord.created_at.desc()).all()

    pacs = db.query(PACS).filter(PACS.id == pacs_id).first()
    pacs_name = pacs.name if pacs else None

    result = []
    for r in records:
        farmer = db.query(Farmer).filter(Farmer.id == r.farmer_id).first()
        crop = db.query(Crop).filter(Crop.id == r.crop_id).first()
        centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == r.centre_id).first()

        result.append(PACSProcurementResponse(
            id=r.id,
            pacs_id=r.pacs_id,
            pacs_name=pacs_name,
            farmer_id=r.farmer_id,
            farmer_name=farmer.full_name if farmer else f"Farmer #{r.farmer_id}",
            farmer_phone=farmer.phone_number if farmer else "",
            centre_id=r.centre_id,
            centre_name=centre.name if centre else "",
            crop_id=r.crop_id,
            crop_name=crop.name if crop else "",
            quantity_quintals=r.quantity_quintals,
            total_amount=r.total_amount,
            status=r.status,
            is_forwarded=r.is_forwarded,
            created_at=r.created_at.isoformat()
        ))
    return result

@router.post("/forward", response_model=PACSProcurementResponse)
def forward_pacs_collection(
    request: PACSForwardRequest,
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    record = db.query(ProcurementRecord).filter(ProcurementRecord.id == request.procurement_record_id).first()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Procurement record not found")

    if record.pacs_id:
        verify_pacs_ownership(payload, record.pacs_id)

    dest_centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == request.destination_centre_id).first()
    if not dest_centre:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Destination procurement centre not found")

    record.centre_id = dest_centre.id
    record.status = "FORWARDED_TO_CENTRE"
    record.is_forwarded = True

    db.commit()
    db.refresh(record)

    pacs = db.query(PACS).filter(PACS.id == record.pacs_id).first() if record.pacs_id else None
    farmer = db.query(Farmer).filter(Farmer.id == record.farmer_id).first()
    crop = db.query(Crop).filter(Crop.id == record.crop_id).first()

    return PACSProcurementResponse(
        id=record.id,
        pacs_id=record.pacs_id,
        pacs_name=pacs.name if pacs else None,
        farmer_id=record.farmer_id,
        farmer_name=farmer.full_name if farmer else "",
        farmer_phone=farmer.phone_number if farmer else "",
        centre_id=record.centre_id,
        centre_name=dest_centre.name,
        crop_id=record.crop_id,
        crop_name=crop.name if crop else "",
        quantity_quintals=record.quantity_quintals,
        total_amount=record.total_amount,
        status=record.status,
        is_forwarded=record.is_forwarded,
        created_at=record.created_at.isoformat()
    )

@router.get("/dispatches", response_model=List[PACSProcurementResponse])
def get_pacs_dispatches(
    pacs_id: int = Query(...),
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    verify_pacs_ownership(payload, pacs_id)
    records = db.query(ProcurementRecord).filter(
        ProcurementRecord.pacs_id == pacs_id
    ).order_by(ProcurementRecord.created_at.desc()).all()

    pacs = db.query(PACS).filter(PACS.id == pacs_id).first()
    pacs_name = pacs.name if pacs else None

    result = []
    for r in records:
        farmer = db.query(Farmer).filter(Farmer.id == r.farmer_id).first()
        crop = db.query(Crop).filter(Crop.id == r.crop_id).first()
        centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == r.centre_id).first()

        result.append(PACSProcurementResponse(
            id=r.id,
            pacs_id=r.pacs_id,
            pacs_name=pacs_name,
            farmer_id=r.farmer_id,
            farmer_name=farmer.full_name if farmer else f"Farmer #{r.farmer_id}",
            farmer_phone=farmer.phone_number if farmer else "",
            centre_id=r.centre_id,
            centre_name=centre.name if centre else "",
            crop_id=r.crop_id,
            crop_name=crop.name if crop else "",
            quantity_quintals=r.quantity_quintals,
            total_amount=r.total_amount,
            status=r.status,
            is_forwarded=r.is_forwarded,
            created_at=r.created_at.isoformat()
        ))
    return result

@router.get("/payments", response_model=List[PACSPaymentResponse])
def get_pacs_payments(
    pacs_id: int = Query(...),
    payload: dict = Depends(RequireRole(["PACS_OPERATOR", "ADMIN", "SUPER_ADMIN"])),
    db: Session = Depends(get_db)
):
    verify_pacs_ownership(payload, pacs_id)
    records = db.query(ProcurementRecord).filter(ProcurementRecord.pacs_id == pacs_id).all()

    result = []
    for r in records:
        farmer = db.query(Farmer).filter(Farmer.id == r.farmer_id).first()
        crop = db.query(Crop).filter(Crop.id == r.crop_id).first()
        pmt = db.query(Payment).filter(Payment.procurement_record_id == r.id).first()

        result.append(PACSPaymentResponse(
            payment_id=pmt.id if pmt else None,
            procurement_record_id=r.id,
            farmer_name=farmer.full_name if farmer else f"Farmer #{r.farmer_id}",
            farmer_phone=farmer.phone_number if farmer else "",
            crop_name=crop.name if crop else "",
            quantity_quintals=r.quantity_quintals,
            amount=r.total_amount,
            payment_reference=pmt.payment_reference if pmt else f"PAY-PACS-{r.id:06d}",
            status=pmt.status if pmt else "SIMULATED_PENDING",
            is_simulated=True,
            created_at=r.created_at.isoformat()
        ))
    return result
