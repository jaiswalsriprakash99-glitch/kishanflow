import os
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.database import Base
from backend.app.models import ProcurementCentre, StaffUser
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_staff_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_staff_pause_centre_mandatory_reason():
    token = create_jwt_token({"sub": "1", "username": "staff1", "role": "CENTRE_STAFF"})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Pause without reason should fail with 400
    res_fail = client.post("/staff/centre/pause", json={"centre_id": 1, "is_paused": True, "delay_reason": ""}, headers=headers)
    assert res_fail.status_code == 400
    assert "mandatory" in res_fail.json()["detail"]

    # 2. Pause with reason succeeds
    db = TestingSessionLocal()
    try:
        centre = db.query(ProcurementCentre).filter(ProcurementCentre.id == 1).first()
        if not centre:
            centre = ProcurementCentre(id=1, name="Mandya Mandi", code="MND_01", centre_type="GOVT_MANDI", latitude=12.5, longitude=76.8, district="Mandya", state="KA")
            db.add(centre)
            db.commit()
    finally:
        db.close()

    res_ok = client.post("/staff/centre/pause", json={"centre_id": 1, "is_paused": True, "delay_reason": "Weighbridge Calibration"}, headers=headers)
    assert res_ok.status_code == 200
    assert res_ok.json()["is_paused"] is True
    assert res_ok.json()["delay_reason"] == "Weighbridge Calibration"

def test_staff_widget_completion_update():
    staff_file = os.path.join(os.getcwd(), 'mobile', 'lib', 'staff', 'staff_dashboard_screen.dart')
    assert os.path.exists(staff_file)
    with open(staff_file, 'r', encoding='utf-8') as f:
        content = f.read()
        assert '_completeFarmer' in content
        assert 'Mark Done' in content
        assert 'Pause Centre Operations' in content
