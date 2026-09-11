import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.database import Base
from database.seed_data import seed_database
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_demo_db():
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
    yield
    Base.metadata.drop_all(bind=test_engine)

def test_demo_reset_disabled_when_demo_mode_false(monkeypatch):
    monkeypatch.setenv("DEMO_MODE", "false")
    admin_token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {admin_token}"}

    res = client.post("/admin/demo-reset", headers=headers)
    assert res.status_code == 403
    assert "Demo Reset endpoint is disabled" in res.json()["detail"]

def test_demo_reset_populates_scenario_when_demo_mode_true(monkeypatch):
    monkeypatch.setenv("DEMO_MODE", "true")
    admin_token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {admin_token}"}

    res = client.post("/admin/demo-reset", headers=headers)
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "ok"
    assert data["demo_mode"] is True
    assert data["active_queue_count"] == 15
    monkeypatch.setenv("DEMO_MODE", "false")
