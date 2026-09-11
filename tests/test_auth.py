import time
import pytest
import bcrypt
from fastapi import Depends
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base
from backend.app.models import StaffUser, Language
from backend.app.routers.auth import OTP_STORE, RATE_LIMIT_STORE, RequireRole
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def init_auth_data():
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        if not db.query(Language).filter(Language.code == "hi").first():
            db.add(Language(code="hi", name="Hindi"))
            db.add(Language(code="en", name="English"))
            db.commit()
    finally:
        db.close()
    yield

def test_send_and_verify_valid_otp():
    phone = "9876543210"
    res = client.post("/auth/send-otp", json={"phone_number": phone})
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    dev_otp = data["dev_otp"]

    res_verify = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": dev_otp})
    assert res_verify.status_code == 200
    v_data = res_verify.json()
    assert "access_token" in v_data
    assert v_data["role"] == "FARMER"

def test_expired_otp_rejected():
    phone = "9876543211"
    client.post("/auth/send-otp", json={"phone_number": phone})
    
    OTP_STORE[phone]["expires_at"] = time.time() - 10

    res = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": "123456"})
    assert res.status_code == 400
    assert "OTP has expired" in res.json()["detail"]

def test_otp_rate_limiting():
    phone = "9876543299"
    RATE_LIMIT_STORE[phone] = []

    for _ in range(3):
        res = client.post("/auth/send-otp", json={"phone_number": phone})
        assert res.status_code == 200

    res_4th = client.post("/auth/send-otp", json={"phone_number": phone})
    assert res_4th.status_code == 429
    assert "Rate limit exceeded" in res_4th.json()["detail"]

def test_staff_login_bcrypt():
    db = TestingSessionLocal()
    try:
        password = "secret_password"
        hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        staff = db.query(StaffUser).filter(StaffUser.username == "test_operator").first()
        if not staff:
            staff = StaffUser(
                username="test_operator",
                full_name="Test Operator",
                hashed_password=hashed,
                role="PACS_OPERATOR"
            )
            db.add(staff)
            db.commit()

        res = client.post("/auth/staff-login", json={"username": "test_operator", "password": password})
        assert res.status_code == 200
        assert res.json()["role"] == "PACS_OPERATOR"

        res_fail = client.post("/auth/staff-login", json={"username": "test_operator", "password": "wrongpassword"})
        assert res_fail.status_code == 401
    finally:
        db.close()

def test_role_check_enforcement():
    phone = "9876543201"
    res_send = client.post("/auth/send-otp", json={"phone_number": phone})
    otp = res_send.json()["dev_otp"]
    res_farmer = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": otp})
    assert res_farmer.status_code == 200
    farmer_token = res_farmer.json()["access_token"]

    @app.get("/test-admin-only", dependencies=[Depends(RequireRole(["ADMIN", "SUPER_ADMIN"]))])
    def admin_only_route():
        return {"ok": True}

    headers = {"Authorization": f"Bearer {farmer_token}"}
    res_forbidden = client.get("/test-admin-only", headers=headers)
    assert res_forbidden.status_code == 403
    assert "Access forbidden" in res_forbidden.json()["detail"]
