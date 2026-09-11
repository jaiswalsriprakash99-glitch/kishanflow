import time
import random
import datetime
import jwt
import bcrypt
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Header
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.config import get_settings
from backend.app.models import Farmer, StaffUser, Language

router = APIRouter(prefix="/auth", tags=["Authentication"])

# In-memory OTP storage for demo & fast access
# Structure: {phone_number: {"otp": "123456", "expires_at": 1690000000, "attempts": 0, "last_sent_at": 1690000000}}
OTP_STORE = {}

# Rate limit window: 60 seconds, max 3 OTP requests
RATE_LIMIT_STORE = {}

class SendOTPRequest(BaseModel):
    phone_number: str

class VerifyOTPRequest(BaseModel):
    phone_number: str
    otp: str

class StaffLoginRequest(BaseModel):
    username: str
    password: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: int

def create_jwt_token(payload: dict) -> str:
    settings = get_settings()
    now = datetime.datetime.utcnow()
    payload_copy = payload.copy()
    payload_copy["iat"] = now
    payload_copy["exp"] = now + datetime.timedelta(days=7)
    token = jwt.encode(payload_copy, settings.JWT_SECRET, algorithm="HS256")
    return token

def decode_jwt_token(token: str) -> dict:
    settings = get_settings()
    try:
        payload = jwt.decode(token, settings.JWT_SECRET, algorithms=["HS256"])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.InvalidTokenError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication token"
        )

# Role Check Dependency Factory
def get_current_user_payload(authorization: Optional[str] = Header(None)) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing or malformed Authorization header"
        )
    token = authorization.split(" ")[1]
    return decode_jwt_token(token)

class RequireRole:
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, payload: dict = Depends(get_current_user_payload)) -> dict:
        user_role = payload.get("role")
        if not user_role or user_role not in self.allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access forbidden: Role '{user_role}' does not have required permissions."
            )
        return payload

@router.post("/send-otp")
def send_otp(request: SendOTPRequest):
    phone = request.phone_number.strip()
    now = time.time()

    # Rate limiting: max 3 requests within 60s
    requests_history = [t for t in RATE_LIMIT_STORE.get(phone, []) if now - t < 60]
    if len(requests_history) >= 3:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded. Please wait a minute before requesting another OTP."
        )

    requests_history.append(now)
    RATE_LIMIT_STORE[phone] = requests_history

    # Generate OTP (in dev/demo mode or default '123456' for predictable testing)
    otp = "123456" if phone.endswith("00") or phone == "9876543201" else f"{random.randint(100000, 999999)}"
    expires_at = now + 300 # 5 minutes

    OTP_STORE[phone] = {
        "otp": otp,
        "expires_at": expires_at,
        "attempts": 0
    }

    return {
        "status": "ok",
        "message": f"OTP sent to {phone}",
        "expires_in_seconds": 300,
        "dev_otp": otp
    }

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(request: VerifyOTPRequest, db: Session = Depends(get_db)):
    phone = request.phone_number.strip()
    user_otp = request.otp.strip()
    now = time.time()

    otp_info = OTP_STORE.get(phone)
    if not otp_info:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No OTP requested for this phone number."
        )

    if now > otp_info["expires_at"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="OTP has expired. Please request a new one."
        )

    if user_otp != otp_info["otp"]:
        otp_info["attempts"] += 1
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid OTP."
        )

    # OTP is valid — clear from store
    del OTP_STORE[phone]

    # Find or create farmer
    farmer = db.query(Farmer).filter(Farmer.phone_number == phone).first()
    if not farmer:
        hindi_lang = db.query(Language).filter(Language.code == "hi").first()
        farmer = Farmer(
            phone_number=phone,
            full_name=f"Farmer {phone[-4:]}",
            preferred_language_id=hindi_lang.id if hindi_lang else None
        )
        db.add(farmer)
        db.commit()
        db.refresh(farmer)

    token = create_jwt_token({
        "sub": str(farmer.id),
        "phone_number": farmer.phone_number,
        "role": "FARMER"
    })

    return TokenResponse(
        access_token=token,
        role="FARMER",
        user_id=farmer.id
    )

@router.post("/staff-login", response_model=TokenResponse)
def staff_login(request: StaffLoginRequest, db: Session = Depends(get_db)):
    username = request.username.strip()
    staff = db.query(StaffUser).filter(StaffUser.username == username).first()

    if not staff:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )

    # Check password using bcrypt
    password_bytes = request.password.encode('utf-8')
    hashed_bytes = staff.hashed_password.encode('utf-8')
    if not bcrypt.checkpw(password_bytes, hashed_bytes):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password"
        )

    token = create_jwt_token({
        "sub": str(staff.id),
        "username": staff.username,
        "role": staff.role,
        "centre_id": staff.centre_id
    })

    return TokenResponse(
        access_token=token,
        role=staff.role,
        user_id=staff.id
    )
