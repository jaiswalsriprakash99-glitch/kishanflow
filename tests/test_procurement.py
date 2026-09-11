import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.database import Base
from backend.app.models import Booking, Slot, ProcurementCentre, Crop
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_procurement_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_out_of_order_status_transition_rejected():
    token = create_jwt_token({"sub": "1", "username": "staff1", "role": "CENTRE_STAFF"})
    headers = {"Authorization": f"Bearer {token}"}

    db = TestingSessionLocal()
    try:
        bk = Booking(
            booking_reference="BK-PROC-001",
            farmer_id=888,
            slot_id=888,
            centre_id=1,
            crop_id=1,
            estimated_quantity_quintals=20.0,
            queue_number=1,
            status="REGISTERED"
        )
        db.add(bk)
        db.commit()
        db.refresh(bk)
        bk_id = bk.id
    finally:
        db.close()

    # 1. Attempt out-of-order transition: REGISTERED directly to WEIGHING (skipping steps!)
    res_invalid = client.post(f"/procurement/{bk_id}/update-status", json={"new_status": "WEIGHING"}, headers=headers)
    assert res_invalid.status_code == 400
    assert "Out-of-order status transition attempt rejected" in res_invalid.json()["detail"]

    # 2. Valid sequential transition: REGISTERED -> SLOT_BOOKED -> ARRIVED
    res_valid1 = client.post(f"/procurement/{bk_id}/update-status", json={"new_status": "SLOT_BOOKED"}, headers=headers)
    assert res_valid1.status_code == 200

    res_valid2 = client.post(f"/procurement/{bk_id}/update-status", json={"new_status": "ARRIVED"}, headers=headers)
    assert res_valid2.status_code == 200

    # 3. Explicit Quality Rejection Branch with Reason
    res_reject = client.post(
        f"/procurement/{bk_id}/update-status",
        json={"new_status": "QUALITY_REJECTED", "rejection_reason": "High Moisture Content (19.2%)"},
        headers=headers
    )
    assert res_reject.status_code == 200
    assert res_reject.json()["new_status"] == "QUALITY_REJECTED"
