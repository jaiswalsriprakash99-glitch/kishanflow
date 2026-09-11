import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.database import Base
from backend.app.models import PACS, ProcurementCentre, ProcurementRecord, Crop, Farmer
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_pacs_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_pacs_collection_and_forwarding_flow():
    token = create_jwt_token({"sub": "1", "username": "pacs_operator1", "role": "PACS_OPERATOR"})
    headers = {"Authorization": f"Bearer {token}"}

    db = TestingSessionLocal()
    try:
        pacs = PACS(name="Test PACS", code="PACS_TEST_99", district="Mysore", state="KA")
        dest_centre = ProcurementCentre(name="Destination Mandi", code="DEST_01", centre_type="GOVT_MANDI", latitude=12.5, longitude=76.8, district="Mandya", state="KA")
        crop = Crop(name="PACS Paddy", code="PPADY", msp_per_quintal=2183.0)
        farmer = Farmer(phone_number="9876599999", full_name="PACS Farmer")
        db.add_all([pacs, dest_centre, crop, farmer])
        db.commit()

        pacs_id, dest_centre_id, crop_id, farmer_id = pacs.id, dest_centre.id, crop.id, farmer.id
    finally:
        db.close()

    # 1. POST /pacs/collection
    col_payload = {
        "pacs_id": pacs_id,
        "farmer_id": farmer_id,
        "crop_id": crop_id,
        "quantity_quintals": 40.0,
        "total_amount": 87320.0
    }
    res_col = client.post("/pacs/collection", json=col_payload, headers=headers)
    assert res_col.status_code == 200
    record_data = res_col.json()
    record_id = record_data["id"]
    assert record_data["status"] == "COLLECTED_AT_PACS"
    assert record_data["is_forwarded"] is False

    # 2. GET /pacs/pending
    res_pending = client.get(f"/pacs/pending?pacs_id={pacs_id}", headers=headers)
    assert res_pending.status_code == 200
    assert len(res_pending.json()) >= 1

    # 3. POST /pacs/forward to main centre
    fwd_payload = {
        "procurement_record_id": record_id,
        "destination_centre_id": dest_centre_id
    }
    res_fwd = client.post("/pacs/forward", json=fwd_payload, headers=headers)
    assert res_fwd.status_code == 200
    fwd_data = res_fwd.json()

    # Verify procurement_record status updated to FORWARDED_TO_CENTRE and is_forwarded = True!
    assert fwd_data["status"] == "FORWARDED_TO_CENTRE"
    assert fwd_data["is_forwarded"] is True
    assert fwd_data["centre_id"] == dest_centre_id
