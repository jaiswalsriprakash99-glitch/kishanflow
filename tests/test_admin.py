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
