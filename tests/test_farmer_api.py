import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.models import Crop
from backend.app.routers.auth import RATE_LIMIT_STORE
from backend.app.database import Base
from database.seed_data import seed_database
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_farmer_db():
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
    yield

@pytest.fixture
def farmer_auth_header():
    phone = "9876543201"
    RATE_LIMIT_STORE[phone] = [] # Reset rate limit for test
    res_send = client.post("/auth/send-otp", json={"phone_number": phone})
    otp = res_send.json()["dev_otp"]
    res_verify = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": otp})
    token = res_verify.json()["access_token"]
    return {"Authorization": f"Bearer {token}"}

def test_get_and_update_farmer_profile(farmer_auth_header):
    res_get = client.get("/farmer/profile", headers=farmer_auth_header)
    assert res_get.status_code == 200
    data_get = res_get.json()
    assert "farmer_id" in data_get

    update_payload = {
        "full_name": "Ramesh Gowda Updated",
        "village": "Srirangapatna",
        "district": "Mandya",
        "state": "Karnataka",
        "pincode": "571401",
        "land_acreage": 8.5,
        "bank_account_no": "501002349801",
        "ifsc_code": "SBIN0001234"
    }
    res_put = client.put("/farmer/profile", json=update_payload, headers=farmer_auth_header)
    assert res_put.status_code == 200
    data_put = res_put.json()
    assert data_put["full_name"] == "Ramesh Gowda Updated"
    assert data_put["land_acreage"] == 8.5
    assert data_put["village"] == "Srirangapatna"

def test_register_farmer_crop(farmer_auth_header):
    db = TestingSessionLocal()
    try:
        crop = db.query(Crop).filter(Crop.name == "Paddy").first()
        if not crop:
            crop = Crop(name="Paddy", code="PDY", msp_per_quintal=2183.0)
            db.add(crop)
            db.commit()
            db.refresh(crop)
        crop_id = crop.id
    finally:
        db.close()

    crop_payload = {
        "crop_id": crop_id,
        "estimated_quantity_quintals": 25.5,
        "land_area_acres": 4.0
    }
    res_crop = client.post("/farmer/crops", json=crop_payload, headers=farmer_auth_header)
    assert res_crop.status_code == 200
    c_data = res_crop.json()
    assert c_data["estimated_quantity_quintals"] == 25.5
    assert c_data["crop_name"] == "Paddy"

def test_invalid_crop_quantity_rejected(farmer_auth_header):
    crop_payload = {
        "crop_id": 1,
        "estimated_quantity_quintals": -5.0,
        "land_area_acres": 2.0
    }
    res_fail = client.post("/farmer/crops", json=crop_payload, headers=farmer_auth_header)
    assert res_fail.status_code == 400
    assert "greater than 0" in res_fail.json()["detail"]
