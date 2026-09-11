import pytest
from backend.app.models import ProcurementCentre, Crop, Slot, Booking, QueueEntry, QueueEvent
from backend.app.services.queue_engine import QueueEngine
from tests.conftest import TestingSessionLocal

def test_queue_position_recalculation_after_completion_and_noshow():
    db = TestingSessionLocal()
    try:
        centre = ProcurementCentre(name="Queue Test Mandi", code="Q_TEST_01", centre_type="GOVT_MANDI", latitude=12.5, longitude=76.8, district="Mandya", state="KA")
        crop = Crop(name="Queue Wheat", code="QWHT", msp_per_quintal=2275.0)
        db.add_all([centre, crop])
        db.commit()

        slot = Slot(centre_id=centre.id, crop_id=crop.id, slot_date="2026-09-30", start_time="09:00", end_time="12:00", capacity=10, booked_count=3)
        db.add(slot)
        db.commit()

        # Create 3 bookings for 3 farmers
        bks = []
        for i in range(1, 4):
            bk = Booking(
                booking_reference=f"BK-Q-{i}",
                farmer_id=i,
                slot_id=slot.id,
                centre_id=centre.id,
                crop_id=crop.id,
                estimated_quantity_quintals=20.0,
                queue_number=i,
                status="SLOT_BOOKED"
            )
            db.add(bk)
            db.flush()
            bks.append(bk)

        # Arrive all 3 farmers -> Positions should be 1, 2, 3
        q1 = QueueEngine.arrive_farmer(db, bks[0].id)
        q2 = QueueEngine.arrive_farmer(db, bks[1].id)
        q3 = QueueEngine.arrive_farmer(db, bks[2].id)
        db.commit()

        assert q1.position == 1
        assert q2.position == 2
        assert q3.position == 3

        # Start and Complete farmer 1 (q1)
        QueueEngine.start_service(db, bks[0].id, counter_id=1)
        QueueEngine.complete_service(db, bks[0].id)
        db.commit()

        # Verify positions recalculated: q2 is now position 1, q3 is now position 2!
        db.refresh(q2)
        db.refresh(q3)
        assert q2.position == 1
        assert q3.position == 2

        # Mark farmer 2 (q2) as NO_SHOW
        QueueEngine.no_show_farmer(db, bks[1].id)
        db.commit()

        # Verify position recalculated: q3 is now position 1!
        db.refresh(q3)
        assert q3.position == 1
        assert q2.status == "NO_SHOW"
        assert q2.position == 0

        # Verify audit log entries in queue_events
        events = db.query(QueueEvent).filter(QueueEvent.centre_id == centre.id).all()
        event_types = [e.event_type for e in events]
        assert "ARRIVED" in event_types
        assert "START" in event_types
        assert "COMPLETED" in event_types
        assert "NO_SHOW" in event_types

    finally:
        db.close()
