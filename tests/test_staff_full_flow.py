import pytest
import bcrypt
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base
from backend.app.models import (
    StaffUser, ProcurementCentre, CentreCounter, Farmer, Crop, Slot, Booking, QueueEntry
)
from backend.app.routers.auth import create_jwt_token
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_staff_flow_db():
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        # Seed test centre
        centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == 100).first()
        if not centre:
            centre = ProcurementCentre(
                id=100,
                name="Testing Mandi Hub",
                code="TST_HUB_100",
                centre_type="GOVT_MANDI",
                latitude=12.5,
                longitude=76.8,
                district="Mandya",
                state="Karnataka",
                total_counters=2
            )
            db.add(centre)
            db.commit()

        # Seed test counter
        counter = db.query(CentreCounter).filter(CentreCounter.id == 100).first()
        if not counter:
            counter = CentreCounter(
                id=100,
                centre_id=100,
                counter_number=1,
                counter_name="Counter #1",
                is_active=True
            )
            db.add(counter)
            db.commit()

        # Seed staff user
        password = "staffpassword123"
        hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
        staff = db.query(StaffUser).filter(StaffUser.username == "test_staff_operator").first()
        if not staff:
            staff = StaffUser(
                username="test_staff_operator",
                full_name="Staff Operator 1",
                hashed_password=hashed,
                role="CENTRE_STAFF",
                centre_id=100
            )
            db.add(staff)
            db.commit()

        # Seed Farmer, Crop, Slot & Booking
        farmer = db.query(Farmer).filter(Farmer.id == 999).first()
        if not farmer:
            farmer = Farmer(id=999, phone_number="9999900000", full_name="Test Farmer Flow")
            db.add(farmer)
            db.commit()

        crop = db.query(Crop).filter(Crop.id == 999).first()
        if not crop:
            crop = Crop(id=999, name="Paddy Test", code="PDY9", msp_per_quintal=2183.0)
            db.add(crop)
            db.commit()

        slot = db.query(Slot).filter(Slot.id == 999).first()
        if not slot:
            slot = Slot(id=999, centre_id=100, crop_id=999, slot_date="2026-09-12", start_time="09:00", end_time="13:00")
            db.add(slot)
            db.commit()

        bk = db.query(Booking).filter(Booking.id == 999).first()
        if not bk:
            bk = Booking(
                id=999,
                booking_reference="BK-STAFF-999",
                farmer_id=999,
                slot_id=999,
                centre_id=100,
                crop_id=999,
                estimated_quantity_quintals=25.0,
                queue_number=1,
                status="REGISTERED"
            )
            db.add(bk)
            db.commit()
    finally:
        db.close()
    yield

def test_full_staff_operational_lifecycle():
    # 1. Staff Login
    res_login = client.post("/auth/staff-login", json={"username": "test_staff_operator", "password": "staffpassword123"})
    assert res_login.status_code == 200
    token = res_login.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    # 2. Staff Dashboard
    res_dash = client.get("/staff/dashboard/100", headers=headers)
    assert res_dash.status_code == 200
    assert res_dash.json()["centre_name"] == "Testing Mandi Hub"

    # 3. Get Schedule
    res_sched = client.get("/staff/centre/100/schedule", headers=headers)
    assert res_sched.status_code == 200
    assert len(res_sched.json()) >= 1

    # 4. Mark Farmer Arrived
    res_arr = client.post("/queue/999/arrive", headers=headers)
    assert res_arr.status_code == 200
    assert res_arr.json()["status"] == "WAITING"

    # 5. Call Next Farmer
    res_call = client.post("/staff/queue/call-next", json={"centre_id": 100, "counter_id": 100}, headers=headers)
    assert res_call.status_code == 200
    assert res_call.json()["booking_id"] == 999

    # 6. Verification
    res_ver = client.post("/staff/procurement/999/verify?verified=true", headers=headers)
    assert res_ver.status_code == 200
    assert res_ver.json()["verified"] is True

    # 7. Quality Check (Pass)
    qc_data = {
        "moisture_content_percent": 14.2,
        "foreign_matter_percent": 1.0,
        "broken_grains_percent": 2.5,
        "grade": "Grade A",
        "passed": True
    }
    res_qc = client.post("/staff/procurement/999/quality-check", json=qc_data, headers=headers)
    assert res_qc.status_code == 200
    assert res_qc.json()["new_status"] == "WEIGHING"

    # 8. Weighment
    weigh_data = {
        "gross_weight_kg": 2550.0,
        "tare_weight_kg": 50.0,
        "bags_count": 50
    }
    res_w = client.post("/staff/procurement/999/weighment", json=weigh_data, headers=headers)
    assert res_w.status_code == 200
    assert res_w.json()["net_weight_kg"] == 2500.0
    assert res_w.json()["net_quintals"] == 25.0

    # 9. Complete Procurement
    res_comp = client.post("/staff/procurement/999/complete", headers=headers)
    assert res_comp.status_code == 200
    assert res_comp.json()["new_status"] == "PROCUREMENT_COMPLETED"

    # 10. Summary
    res_sum = client.get("/staff/summary/100", headers=headers)
    assert res_sum.status_code == 200
    assert res_sum.json()["completed_farmers"] == 1
    assert res_sum.json()["total_procured_quintals"] == 25.0
