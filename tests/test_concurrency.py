import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.models import Slot, ProcurementCentre, Crop
from backend.app.routers.auth import RATE_LIMIT_STORE
from tests.conftest import TestingSessionLocal

client = TestClient(app)

def create_farmer_token(phone: str) -> str:
    RATE_LIMIT_STORE[phone] = []
    res_send = client.post("/auth/send-otp", json={"phone_number": phone})
    otp = res_send.json()["dev_otp"]
    res_verify = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": otp})
    return res_verify.json()["access_token"]

def test_simultaneous_booking_concurrency_last_seat():
    db = TestingSessionLocal()
    try:
        centre = ProcurementCentre(name="Concurrency Test Mandi", code="CONCUR_01", centre_type="GOVT_MANDI", latitude=12.5, longitude=76.8, district="Mandya", state="KA")
        crop = Crop(name="Test Wheat", code="TWHT", msp_per_quintal=2200.0)
        db.add_all([centre, crop])
        db.commit()

        slot = Slot(
            centre_id=centre.id,
            crop_id=crop.id,
            slot_date="2026-09-20",
            start_time="09:00",
            end_time="10:00",
            capacity=1, # EXACTLY 1 SEAT AVAILABLE
            booked_count=0
        )
        db.add(slot)
        db.commit()
        slot_id = slot.id
        crop_id = crop.id
    finally:
        db.close()

    token1 = create_farmer_token("9900000001")
    token2 = create_farmer_token("9900000002")

    headers1 = {"Authorization": f"Bearer {token1}"}
    headers2 = {"Authorization": f"Bearer {token2}"}

    payload = {
        "slot_id": slot_id,
        "crop_id": crop_id,
        "estimated_quantity_quintals": 10.0
    }

    # First booking request succeeds
    res1 = client.post("/bookings", json=payload, headers=headers1)
    assert res1.status_code == 200
    assert res1.json()["queue_number"] == 1

    # Second booking request for the last seat fails because capacity is reached (1/1 booked)
    res2 = client.post("/bookings", json=payload, headers=headers2)
    assert res2.status_code == 400
    assert "Slot capacity reached" in res2.json()["detail"]

    # Verify final slot booked_count in database is exactly 1 (no overbooking!)
    db = TestingSessionLocal()
    try:
        updated_slot = db.query(Slot).filter(Slot.id == slot_id).first()
        assert updated_slot.booked_count == 1
    finally:
        db.close()
