import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.models import ProcurementCentre, Crop, Slot
from backend.app.routers.auth import RATE_LIMIT_STORE
from tests.conftest import TestingSessionLocal

client = TestClient(app)

def create_farmer_token(phone: str) -> str:
    RATE_LIMIT_STORE[phone] = []
    res_send = client.post("/auth/send-otp", json={"phone_number": phone})
    otp = res_send.json()["dev_otp"]
    res_verify = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": otp})
    return res_verify.json()["access_token"]

def test_get_slots_and_booking_lifecycle():
    db = TestingSessionLocal()
    try:
        centre = ProcurementCentre(name="Booking Test Mandi", code="BK_TEST_01", centre_type="GOVT_MANDI", latitude=12.5, longitude=76.8, district="Mandya", state="KA")
        crop = Crop(name="Booking Paddy", code="BPDY", msp_per_quintal=2183.0)
        db.add_all([centre, crop])
        db.commit()

        slot1 = Slot(centre_id=centre.id, crop_id=crop.id, slot_date="2026-09-25", start_time="09:00", end_time="11:00", capacity=10, booked_count=0)
        slot2 = Slot(centre_id=centre.id, crop_id=crop.id, slot_date="2026-09-25", start_time="11:00", end_time="13:00", capacity=10, booked_count=0)
        db.add_all([slot1, slot2])
        db.commit()
        c_id, slot1_id, slot2_id, cr_id = centre.id, slot1.id, slot2.id, crop.id
    finally:
        db.close()

    # GET Slots
    res_slots = client.get(f"/centres/{c_id}/slots")
    assert res_slots.status_code == 200
    assert len(res_slots.json()) >= 2

    # POST Create Booking
    token = create_farmer_token("9876500001")
    headers = {"Authorization": f"Bearer {token}"}
    res_bk = client.post("/bookings", json={"slot_id": slot1_id, "crop_id": cr_id, "estimated_quantity_quintals": 15.0}, headers=headers)
    assert res_bk.status_code == 200
    bk_data = res_bk.json()
    booking_id = bk_data["id"]
    assert bk_data["status"] == "SLOT_BOOKED"

    # POST Reschedule Booking to Slot 2
    res_resched = client.post(f"/bookings/{booking_id}/reschedule", json={"new_slot_id": slot2_id}, headers=headers)
    assert res_resched.status_code == 200
    assert res_resched.json()["slot_id"] == slot2_id

    # POST Cancel Booking
    res_cancel = client.post(f"/bookings/{booking_id}/cancel", headers=headers)
    assert res_cancel.status_code == 200
    assert res_cancel.json()["status"] == "ok"
