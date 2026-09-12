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

    token = create_jwt_token({"sub": "1", "username": "pacs_operator1", "role": "PACS_OPERATOR", "pacs_id": pacs_id})
    headers = {"Authorization": f"Bearer {token}"}

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

    assert fwd_data["status"] == "FORWARDED_TO_CENTRE"
    assert fwd_data["is_forwarded"] is True
    assert fwd_data["centre_id"] == dest_centre_id

def test_cross_pacs_authorization_rejection():
    db = TestingSessionLocal()
    try:
        pacs_a = PACS(name="PACS Alpha", code="PACS_ALPHA", district="District A", state="KA")
        pacs_b = PACS(name="PACS Beta", code="PACS_BETA", district="District B", state="KA")
        db.add_all([pacs_a, pacs_b])
        db.commit()
        pacs_a_id, pacs_b_id = pacs_a.id, pacs_b.id
    finally:
        db.close()

    # Operator token for PACS Alpha
    token_a = create_jwt_token({"sub": "10", "username": "op_alpha", "role": "PACS_OPERATOR", "pacs_id": pacs_a_id})
    headers_a = {"Authorization": f"Bearer {token_a}"}

    # Accessing PACS Beta dashboard with PACS Alpha token MUST return 403 Forbidden
    res_b_dash = client.get(f"/pacs/dashboard-summary?pacs_id={pacs_b_id}", headers=headers_a)
    assert res_b_dash.status_code == 403
    assert "Forbidden" in res_b_dash.json()["detail"]

    # Submitting collection for PACS Beta with PACS Alpha token MUST return 403 Forbidden
    col_payload = {
        "pacs_id": pacs_b_id,
        "farmer_id": 1,
        "crop_id": 1,
        "quantity_quintals": 10.0
    }
    res_b_col = client.post("/pacs/collection", json=col_payload, headers=headers_a)
    assert res_b_col.status_code == 403

def test_invalid_quantity_rejection():
    db = TestingSessionLocal()
    try:
        pacs = PACS(name="Quant PACS", code="PACS_QTY", district="Dist", state="ST")
        farmer = Farmer(phone_number="9111111111", full_name="Qty Farmer")
        crop = Crop(name="Qty Crop", code="QCR", msp_per_quintal=1000.0)
        db.add_all([pacs, farmer, crop])
        db.commit()
        p_id, f_id, c_id = pacs.id, farmer.id, crop.id
    finally:
        db.close()

    token = create_jwt_token({"sub": "11", "username": "op_qty", "role": "PACS_OPERATOR", "pacs_id": p_id})
    headers = {"Authorization": f"Bearer {token}"}

    # Zero quantity
    res_zero = client.post("/pacs/collection", json={
        "pacs_id": p_id, "farmer_id": f_id, "crop_id": c_id, "quantity_quintals": 0.0
    }, headers=headers)
    assert res_zero.status_code == 400

    # Negative quantity
    res_neg = client.post("/pacs/collection", json={
        "pacs_id": p_id, "farmer_id": f_id, "crop_id": c_id, "quantity_quintals": -15.0
    }, headers=headers)
    assert res_neg.status_code == 400

def test_duplicate_collection_prevention():
    db = TestingSessionLocal()
    try:
        pacs = PACS(name="Dup PACS", code="PACS_DUP", district="Dist", state="ST")
        farmer = Farmer(phone_number="9222222222", full_name="Dup Farmer")
        crop = Crop(name="Dup Crop", code="DCR", msp_per_quintal=1500.0)
        db.add_all([pacs, farmer, crop])
        db.commit()
        p_id, f_id, c_id = pacs.id, farmer.id, crop.id
    finally:
        db.close()

    token = create_jwt_token({"sub": "12", "username": "op_dup", "role": "PACS_OPERATOR", "pacs_id": p_id})
    headers = {"Authorization": f"Bearer {token}"}

    payload = {"pacs_id": p_id, "farmer_id": f_id, "crop_id": c_id, "quantity_quintals": 25.0}

    # First submission should succeed
    res1 = client.post("/pacs/collection", json=payload, headers=headers)
    assert res1.status_code == 200

    # Second submission on same day for same farmer & crop should be rejected as duplicate
    res2 = client.post("/pacs/collection", json=payload, headers=headers)
    assert res2.status_code == 400
    assert "Duplicate collection attempt" in res2.json()["detail"]

def test_pacs_dashboard_and_queries():
    db = TestingSessionLocal()
    try:
        pacs = PACS(name="Dash PACS", code="PACS_DASH", district="Mysore", state="KA")
        farmer = Farmer(phone_number="9333333333", full_name="Dash Farmer")
        crop = Crop(name="Dash Crop", code="DSHCR", msp_per_quintal=2000.0)
        db.add_all([pacs, farmer, crop])
        db.commit()
        p_id = pacs.id
    finally:
        db.close()

    token = create_jwt_token({"sub": "13", "username": "op_dash", "role": "PACS_OPERATOR", "pacs_id": p_id})
    headers = {"Authorization": f"Bearer {token}"}

    # Dashboard summary
    res_dash = client.get(f"/pacs/dashboard-summary?pacs_id={p_id}", headers=headers)
    assert res_dash.status_code == 200
    dash_data = res_dash.json()
    assert dash_data["pacs_name"] == "Dash PACS"
    assert dash_data["operational_status"] == "ACTIVE"

    # Farmer search
    res_search = client.get(f"/pacs/farmers/search?pacs_id={p_id}&query=Dash", headers=headers)
    assert res_search.status_code == 200
    assert len(res_search.json()) >= 1
    assert res_search.json()[0]["full_name"] == "Dash Farmer"

    # Payments read-only check
    res_pmt = client.get(f"/pacs/payments?pacs_id={p_id}", headers=headers)
    assert res_pmt.status_code == 200
    assert isinstance(res_pmt.json(), list)
