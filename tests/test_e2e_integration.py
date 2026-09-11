import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base
from backend.app.services.queue_engine import QueueEngine
from backend.app.models import ProcurementRecord
from backend.app.routers.auth import RATE_LIMIT_STORE, create_jwt_token
from database.seed_data import seed_database
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_e2e_db():
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
    yield
    Base.metadata.drop_all(bind=test_engine)

def test_full_system_integration_lifecycle():
    phone = "9876588888"
    RATE_LIMIT_STORE[phone] = []

    # 1. Farmer Authentication
    res = client.post("/auth/send-otp", json={"phone_number": phone})
    assert res.status_code == 200
    otp = res.json().get("dev_otp", "123456")

    res = client.post("/auth/verify-otp", json={"phone_number": phone, "otp": otp})
    assert res.status_code == 200
    farmer_token = res.json()["access_token"]
    farmer_headers = {"Authorization": f"Bearer {farmer_token}"}

    # 2. Farmer Profile & Crop Registration
    res = client.put("/farmer/profile", json={
        "father_name": "Ramesh Senior",
        "village": "Mandya Village",
        "district": "Mandya",
        "state": "Karnataka",
        "pincode": "571401",
        "land_acreage": 5.5,
        "bank_account_no": "9998887771",
        "ifsc_code": "SBIN0001111"
    }, headers=farmer_headers)
    assert res.status_code == 200

    res = client.post("/farmer/crops", json={
        "crop_id": 1,
        "estimated_quantity_quintals": 45.0,
        "land_area_acres": 5.5
    }, headers=farmer_headers)
    assert res.status_code == 200

    # 3. Centre Discovery & Slot Booking
    res = client.get("/centres?latitude=12.52&longitude=76.89", headers=farmer_headers)
    assert res.status_code == 200
    centres = res.json()
    assert len(centres) > 0
    centre_id = centres[0]["id"]

    res = client.get(f"/centres/{centre_id}/slots", headers=farmer_headers)
    assert res.status_code == 200
    slots = res.json()
    assert len(slots) > 0
    slot = slots[0]

    res = client.post("/bookings", json={
        "slot_id": slot["id"],
        "crop_id": slot["crop_id"],
        "estimated_quantity_quintals": 30.0
    }, headers=farmer_headers)
    assert res.status_code == 200
    booking_data = res.json()
    booking_id = booking_data["id"]
    assert "booking_reference" in booking_data

    # 4. AI Wait Time Prediction & Dynamic Guidance
    res = client.post("/predictions/waiting-time", json={
        "booking_id": booking_id,
        "centre_id": centre_id,
        "quantity": 30.0,
        "farmers_ahead": 4,
        "active_counters": 2,
        "travel_time_minutes": 20.0
    })
    assert res.status_code == 200
    pred = res.json()
    assert pred["predicted_wait_minutes"] > 0
    assert "recommended_arrival_time" in pred
    assert "recommended_departure_time" in pred
    assert len(pred["reasons"]) > 0

    # 5. Queue Engine State Machine Lifecycle (Check-in -> Processing -> Completed)
    db = TestingSessionLocal()
    try:
        q_entry = QueueEngine.arrive_farmer(db, booking_id)
        assert q_entry.status == "WAITING"

        q_entry = QueueEngine.start_service(db, booking_id, counter_id=1, staff_id=1)
        assert q_entry.status == "PROCESSING"

        q_entry = QueueEngine.complete_service(db, booking_id, staff_id=1)
        assert q_entry.status == "COMPLETED"
        assert q_entry.actual_wait_minutes is not None

        # Create Procurement Record
        proc_record = ProcurementRecord(
            booking_id=booking_id,
            farmer_id=1,
            centre_id=centre_id,
            crop_id=slot["crop_id"],
            quantity_quintals=30.0,
            total_amount=30.0 * 2183.0,
            status="ACCEPTED",
            pacs_id=1,
            is_forwarded=False
        )
        db.add(proc_record)
        db.commit()
        proc_id = proc_record.id
    finally:
        db.close()

    # 6. PACS Collection & Forwarding Workflow
    pacs_token = create_jwt_token({"sub": "10", "username": "pacs_op", "role": "PACS_OPERATOR"})
    pacs_headers = {"Authorization": f"Bearer {pacs_token}"}

    res = client.get("/pacs/pending?pacs_id=1", headers=pacs_headers)
    assert res.status_code == 200

    res = client.post("/pacs/forward", json={
        "procurement_record_id": proc_id,
        "destination_centre_id": centre_id
    }, headers=pacs_headers)
    assert res.status_code == 200

    # 7. Procurement Status Timeline Progression (Current status is VERIFICATION)
    staff_token = create_jwt_token({"sub": "11", "username": "staff_op", "role": "CENTRE_STAFF"})
    staff_headers = {"Authorization": f"Bearer {staff_token}"}

    # Step 1: VERIFICATION -> QUALITY_CHECK
    res = client.post(f"/procurement/{booking_id}/update-status", json={"new_status": "QUALITY_CHECK"}, headers=staff_headers)
    assert res.status_code == 200

    # Step 2: QUALITY_CHECK -> WEIGHING
    res = client.post(f"/procurement/{booking_id}/update-status", json={"new_status": "WEIGHING"}, headers=staff_headers)
    assert res.status_code == 200

    # Step 3: WEIGHING -> ACCEPTED
    res = client.post(f"/procurement/{booking_id}/update-status", json={"new_status": "ACCEPTED"}, headers=staff_headers)
    assert res.status_code == 200

    # 8. Payment Simulation Lifecycle
    # Initial status check
    res_pay1 = client.get(f"/payment/{booking_id}")
    assert res_pay1.status_code == 200
    pay_data1 = res_pay1.json()
    assert pay_data1["status"] == "INITIATED"
    assert pay_data1["is_simulated"] is True

    # Progress to PROCESSING
    res_pay2 = client.post(f"/payment/{booking_id}/trigger-simulated-payment", headers=farmer_headers)
    assert res_pay2.status_code == 200
    assert res_pay2.json()["status"] == "PROCESSING"

    # Progress to CREDITED
    res_pay3 = client.post(f"/payment/{booking_id}/trigger-simulated-payment", headers=farmer_headers)
    assert res_pay3.status_code == 200
    assert res_pay3.json()["status"] == "CREDITED"
    assert res_pay3.json()["is_simulated"] is True

    # 9. Admin Operations & Executive Analytics Audit
    admin_token = create_jwt_token({"sub": "12", "username": "admin_op", "role": "ADMIN"})
    admin_headers = {"Authorization": f"Bearer {admin_token}"}

    res = client.get("/admin/analytics", headers=admin_headers)
    assert res.status_code == 200
    analytics = res.json()
    assert analytics["total_bookings"] > 0

    res = client.get("/admin/analytics/predicted-vs-actual", headers=admin_headers)
    assert res.status_code == 200
    pred_vs_act = res.json()
    assert pred_vs_act["total_predictions"] > 0
