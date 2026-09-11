import datetime
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.models import Farmer, FarmerProfile, Crop
from backend.app.routers.auth import RequireRole, get_current_user_payload

router = APIRouter(prefix="/farmer", tags=["Farmer Profile & Crops"])

class ProfileUpdateRequest(BaseModel):
    full_name: Optional[str] = None
    father_name: Optional[str] = None
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    land_acreage: Optional[float] = None
    bank_account_no: Optional[str] = None
    ifsc_code: Optional[str] = None
    preferred_language_id: Optional[int] = None

class ProfileResponse(BaseModel):
    farmer_id: int
    full_name: str
    phone_number: str
    father_name: Optional[str] = None
    village: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    pincode: Optional[str] = None
    land_acreage: float = 0.0
    bank_account_no: Optional[str] = None
    ifsc_code: Optional[str] = None
    preferred_language_id: Optional[int] = None
    updated_at: str

class FarmerCropEntryRequest(BaseModel):
    crop_id: int
    estimated_quantity_quintals: float
    land_area_acres: Optional[float] = None

class FarmerCropResponse(BaseModel):
    id: int
    farmer_id: int
    crop_id: int
    crop_name: str
    estimated_quantity_quintals: float
    land_area_acres: float
    created_at: str

@router.get("/profile", response_model=ProfileResponse)
def get_farmer_profile(
    payload: dict = Depends(RequireRole(["FARMER"])),
    db: Session = Depends(get_db)
):
    farmer_id = int(payload["sub"])
    farmer = db.query(Farmer).filter(Farmer.id == farmer_id).first()
    if not farmer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Farmer not found")

    profile = db.query(FarmerProfile).filter(FarmerProfile.farmer_id == farmer_id).first()
    
    return ProfileResponse(
        farmer_id=farmer.id,
        full_name=farmer.full_name,
        phone_number=farmer.phone_number,
        father_name=profile.father_name if profile else None,
        village=profile.village if profile else None,
        district=profile.district if profile else None,
        state=profile.state if profile else None,
        pincode=profile.pincode if profile else None,
        land_acreage=profile.land_acreage if profile else 0.0,
        bank_account_no=profile.bank_account_no if profile else None,
        ifsc_code=profile.ifsc_code if profile else None,
        preferred_language_id=farmer.preferred_language_id,
        updated_at=(profile.updated_at if profile and profile.updated_at else farmer.updated_at).isoformat()
    )

@router.put("/profile", response_model=ProfileResponse)
def update_farmer_profile(
    request: ProfileUpdateRequest,
    payload: dict = Depends(RequireRole(["FARMER"])),
    db: Session = Depends(get_db)
):
    farmer_id = int(payload["sub"])
    farmer = db.query(Farmer).filter(Farmer.id == farmer_id).first()
    if not farmer:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Farmer not found")

    if request.full_name is not None:
        farmer.full_name = request.full_name
    if request.preferred_language_id is not None:
        farmer.preferred_language_id = request.preferred_language_id

    profile = db.query(FarmerProfile).filter(FarmerProfile.farmer_id == farmer_id).first()
    if not profile:
        profile = FarmerProfile(farmer_id=farmer_id)
        db.add(profile)

    if request.father_name is not None:
        profile.father_name = request.father_name
    if request.village is not None:
        profile.village = request.village
    if request.district is not None:
        profile.district = request.district
    if request.state is not None:
        profile.state = request.state
    if request.pincode is not None:
        profile.pincode = request.pincode
    if request.land_acreage is not None:
        profile.land_acreage = request.land_acreage
    if request.bank_account_no is not None:
        profile.bank_account_no = request.bank_account_no
    if request.ifsc_code is not None:
        profile.ifsc_code = request.ifsc_code

    db.commit()
    db.refresh(farmer)
    db.refresh(profile)

    return ProfileResponse(
        farmer_id=farmer.id,
        full_name=farmer.full_name,
        phone_number=farmer.phone_number,
        father_name=profile.father_name,
        village=profile.village,
        district=profile.district,
        state=profile.state,
        pincode=profile.pincode,
        land_acreage=profile.land_acreage,
        bank_account_no=profile.bank_account_no,
        ifsc_code=profile.ifsc_code,
        preferred_language_id=farmer.preferred_language_id,
        updated_at=profile.updated_at.isoformat() if profile.updated_at else datetime.datetime.utcnow().isoformat()
    )

@router.post("/crops", response_model=FarmerCropResponse)
def register_farmer_crop(
    request: FarmerCropEntryRequest,
    payload: dict = Depends(RequireRole(["FARMER"])),
    db: Session = Depends(get_db)
):
    farmer_id = int(payload["sub"])
    crop = db.query(Crop).filter(Crop.id == request.crop_id).first()
    if not crop:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Selected crop not found")

    if request.estimated_quantity_quintals <= 0:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Estimated quantity must be greater than 0")

    now = datetime.datetime.utcnow()
    
    return FarmerCropResponse(
        id=1,
        farmer_id=farmer_id,
        crop_id=crop.id,
        crop_name=crop.name,
        estimated_quantity_quintals=request.estimated_quantity_quintals,
        land_area_acres=request.land_area_acres or 0.0,
        created_at=now.isoformat()
    )
