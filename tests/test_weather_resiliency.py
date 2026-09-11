import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base
from backend.app.models import ProcurementCentre, Crop, Slot, Booking
from backend.app.routers.auth import RATE_LIMIT_STORE
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_weather_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_core_flows_work_when_weather_and_mapbox_keys_disabled(monkeypatch):
    monkeypatch.setenv("OPENWEATHERMAP_API_KEY", "")
    monkeypatch.setenv("MAPBOX_API_KEY", "")

    # Create a test centre in DB first
    db = TestingSessionLocal()
    try:
        centre = db.query(ProcurementCentre).first()
        if not centre:
            centre = ProcurementCentre(name="Resilient Mandi", code="RES_01", centre_type="GOVT_MANDI", latitude=12.5, longitude=76.8, district="Mandya", state="KA")
            db.add(centre)
            db.commit()
            db.refresh(centre)
        c_id = centre.id
    finally:
        db.close()

    # 1. Verify GET /weather works with fallback
    res_w = client.get(f"/weather?centre_id={c_id}")
    assert res_w.status_code == 200
    data_w = res_w.json()
    assert data_w["risk_level"] in ["LOW", "MODERATE", "HIGH"]
    assert data_w["source"] == "approximate"

    # 2. Verify GET /travel-time works with straight-line fallback
    res_t = client.get(f"/travel-time?centre_id={c_id}&farmer_lat=12.5000&farmer_lng=76.8000")
    assert res_t.status_code == 200
    data_t = res_t.json()
    assert data_t["source"] == "approximate"
    assert data_t["travel_time_minutes"] > 0.0

    # 3. Verify core slot booking flow works end-to-end when keys disabled
    db = TestingSessionLocal()
    try:
        crop = Crop(name="Resilient Paddy", code="RPDY", msp_per_quintal=2183.0)
        db.add(crop)
        db.commit()

        slot = Slot(centre_id=c_id, crop_id=crop.id, slot_date="2026-10-01", start_time="09:00", end_time="11:00", capacity=10, booked_count=0)
        db.add(slot)
        db.commit()

        phone = "9888800099"
        RATE_LIMIT_STORE[phone] = []
        res_send = client.post("/auth/send-otp", json={"phone_number": phone})
        otp = res_send.json()["dev_otp"]
        token = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": otp}).json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        res_bk = client.post("/bookings", json={"slot_id": slot.id, "crop_id": crop.id, "estimated_quantity_quintals": 12.0}, headers=headers)
        assert res_bk.status_code == 200
        bk_id = res_bk.json()["id"]

        res_arr = client.post(f"/queue/{bk_id}/arrive", headers=headers)
        assert res_arr.status_code == 200
        assert res_arr.json()["status"] == "WAITING"

        res_pred = client.post("/predictions/waiting-time", json={"booking_id": bk_id, "centre_id": c_id, "travel_time_minutes": data_t["travel_time_minutes"]})
        assert res_pred.status_code == 200
        assert "recommended_departure_time" in res_pred.json()

    finally:
        db.close()
