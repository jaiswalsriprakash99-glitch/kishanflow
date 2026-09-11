import os
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.database import Base
from backend.app.models import Booking, Payment
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_payment_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_simulated_payment_lifecycle_and_is_simulated_flag():
    token = create_jwt_token({"sub": "1", "phone_number": "9876543201", "role": "FARMER"})
    headers = {"Authorization": f"Bearer {token}"}

    db = TestingSessionLocal()
    try:
        bk = Booking(
            booking_reference="BK-PAY-001",
            farmer_id=777,
            slot_id=777,
            centre_id=1,
            crop_id=1,
            estimated_quantity_quintals=25.0,
            queue_number=1,
            status="PROCUREMENT_COMPLETED"
        )
        db.add(bk)
        db.commit()
        db.refresh(bk)
        bk_id = bk.id
    finally:
        db.close()

    # 1. GET /payment/{booking_id} -> Initial INITIATED state
    res1 = client.get(f"/payment/{bk_id}")
    assert res1.status_code == 200
    data1 = res1.json()
    assert data1["status"] == "INITIATED"
    # MUST BE ALWAYS TRUE
    assert data1["is_simulated"] is True
    assert "SIM-DBT" in data1["payment_reference"]

    # 2. Trigger progress 1: INITIATED -> PROCESSING
    res2 = client.post(f"/payment/{bk_id}/trigger-simulated-payment", headers=headers)
    assert res2.status_code == 200
    data2 = res2.json()
    assert data2["status"] == "PROCESSING"
    assert data2["is_simulated"] is True

    # 3. Trigger progress 2: PROCESSING -> CREDITED
    res3 = client.post(f"/payment/{bk_id}/trigger-simulated-payment", headers=headers)
    assert res3.status_code == 200
    data3 = res3.json()
    assert data3["status"] == "CREDITED"
    assert data3["is_simulated"] is True
    assert data3["credited_at"] is not None

def test_flutter_payment_screen_badge_code():
    pay_screen_file = os.path.join(os.getcwd(), 'mobile', 'lib', 'farmer', 'payment_status_screen.dart')
    assert os.path.exists(pay_screen_file)
    with open(pay_screen_file, 'r', encoding='utf-8') as f:
        content = f.read()
        assert 'Demo / Simulated Payment System' in content
        assert 'simulatedBadgeWidget' in content
