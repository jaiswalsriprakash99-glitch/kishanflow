import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.database import Base
from backend.app.models import Farmer, Booking, QueueEntry
from database.seed_data import seed_database
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_admin_db():
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
    yield
    Base.metadata.drop_all(bind=test_engine)

def test_admin_analytics_aggregates_match_direct_db_query():
    token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Call GET /admin/analytics endpoint
    res = client.get("/admin/analytics", headers=headers)
    assert res.status_code == 200
    analytics = res.json()

    # 2. Direct DB Query verification
    db = TestingSessionLocal()
    try:
        db_total_farmers = db.query(Farmer).count()
        db_total_bookings = db.query(Booking).count()
        db_active_queues = db.query(QueueEntry).filter(QueueEntry.status.in_(["WAITING", "PROCESSING"])).count()

        # Assert aggregate numbers from API match direct DB queries EXACTLY!
        assert analytics["total_farmers"] == db_total_farmers
        assert analytics["total_bookings"] == db_total_bookings
        assert analytics["active_queues"] == db_active_queues
        assert "average_waiting_time" in analytics
        assert "no_show_rate" in analytics
    finally:
        db.close()

def test_admin_predicted_vs_actual_analytics():
    token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/admin/analytics/predicted-vs-actual", headers=headers)
    assert res.status_code == 200
    data = res.json()

    assert "total_predictions" in data
    assert "mean_absolute_error_minutes" in data
    assert "within_15min_accuracy_percent" in data
    assert "items" in data
    assert len(data["items"]) > 0

    first = data["items"][0]
    assert "booking_id" in first
    assert "predicted_wait_minutes" in first
    assert "actual_wait_minutes" in first
    assert "difference_minutes" in first
    assert "absolute_error_minutes" in first
    assert first["absolute_error_minutes"] == round(abs(first["predicted_wait_minutes"] - first["actual_wait_minutes"]), 1)

def test_admin_dashboard_stats():
    token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    res = client.get("/admin/dashboard-stats", headers=headers)
    assert res.status_code == 200
    stats = res.json()
    assert "total_centres" in stats
    assert stats["total_centres"] >= 3
    assert "open_centres" in stats
    assert "total_bookings_today" in stats
    assert "payment_completed" in stats
    assert "accepted_quintals" in stats

def test_admin_centre_details_and_mutation():
    token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    # 1. Get centre details
    res = client.get("/admin/centres/1", headers=headers)
    assert res.status_code == 200
    details = res.json()
    assert details["centre"]["id"] == 1
    assert "counters" in details
    assert "live_queue" in details
    assert "procurement_summary" in details

    # 2. Update centre operational status
    pause_res = client.post("/admin/centres/1/status", json={"is_paused": True, "delay_reason": "Maintenance"}, headers=headers)
    assert pause_res.status_code == 200
    assert pause_res.json()["is_active"] is False

    # 3. Verify audit log was created
    audit_res = client.get("/admin/audit-logs", headers=headers)
    assert audit_res.status_code == 200
    logs = audit_res.json()
    assert len(logs) > 0
    assert any(l["action"] == "UPDATE_CENTRE_OPERATIONAL_STATUS" for l in logs)

def test_admin_search_and_pacs():
    token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    # Search
    search_res = client.get("/admin/search?query=Ramesh", headers=headers)
    assert search_res.status_code == 200
    results = search_res.json()
    assert len(results) > 0

    # PACS overview
    pacs_res = client.get("/admin/pacs-overview", headers=headers)
    assert pacs_res.status_code == 200
    p_data = pacs_res.json()
    assert p_data["total_pacs"] >= 1
    assert "pacs" in p_data

def test_admin_alerts_and_model_info():
    token = create_jwt_token({"sub": "1", "username": "admin1", "role": "ADMIN"})
    headers = {"Authorization": f"Bearer {token}"}

    # Alerts
    alerts_res = client.get("/admin/alerts", headers=headers)
    assert alerts_res.status_code == 200
    alerts = alerts_res.json()
    assert isinstance(alerts, list)
    assert len(alerts) > 0

    # Model info
    model_res = client.get("/admin/model-info", headers=headers)
    assert model_res.status_code == 200
    m_info = model_res.json()
    assert "mae_minutes" in m_info
    assert "within_15min_accuracy_percent" in m_info
    assert "evaluation_dataset_note" in m_info

