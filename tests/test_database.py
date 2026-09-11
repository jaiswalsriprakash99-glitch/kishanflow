import pytest
from sqlalchemy import inspect
from backend.app.models import (
    ProcurementCentre, PACS, Farmer, Booking, QueueEntry, Slot, Crop
)
from database.seed_data import seed_database
from tests.conftest import test_engine, TestingSessionLocal

def test_database_tables_and_seed_data():
    db = TestingSessionLocal()
    try:
        seed_database(db)
        
        inspector = inspect(test_engine)
        table_names = inspector.get_table_names()

        required_tables = [
            "farmers", "farmer_profiles", "languages", "pacs", "procurement_centres",
            "centre_counters", "staff_users", "crops", "slots", "bookings",
            "queue_entries", "queue_events", "procurement_records", "quality_checks",
            "weighments", "payments", "notifications", "weather_snapshots",
            "vehicle_costs", "ai_predictions", "audit_logs", "app_configurations"
        ]
        for table in required_tables:
            assert table in table_names, f"Table {table} missing from database"

        centres = db.query(ProcurementCentre).all()
        assert len(centres) >= 3
        centre_types = {c.centre_type for c in centres}
        assert "PACS" in centre_types
        assert "GOVT_MANDI" in centre_types

        farmers_count = db.query(Farmer).count()
        assert farmers_count >= 50

        synthetic_bookings = db.query(Booking).filter(Booking.is_synthetic == True).all()
        assert len(synthetic_bookings) > 0

        booking_indexes = inspector.get_indexes("bookings")
        has_slot_index = any("slot_id" in idx.get("column_names", []) for idx in booking_indexes)
        assert has_slot_index, "Missing slot_id index on bookings"

    finally:
        db.close()
