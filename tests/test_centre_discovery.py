import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.models import ProcurementCentre, CentreCounter, QueueEntry, Booking
from tests.conftest import TestingSessionLocal

client = TestClient(app)

def test_centre_ranking_order():
    db = TestingSessionLocal()
    try:
        # Create 3 fixed mock centres
        # Centre A: Close (1 km), long queue (20 waiting), 1 counter
        # Centre B: Moderate dist (5 km), empty queue (0 waiting), 2 counters -> Should rank BEST!
        # Centre C: Very far (50 km), empty queue (0 waiting), 2 counters
        c_a = ProcurementCentre(name="Centre A", code="CENTRE_A", centre_type="GOVT_MANDI", latitude=12.5220, longitude=76.8960, district="Mandya", state="KA", total_counters=1)
        c_b = ProcurementCentre(name="Centre B", code="CENTRE_B", centre_type="PACS", latitude=12.5600, longitude=76.9200, district="Mandya", state="KA", total_counters=2)
        c_c = ProcurementCentre(name="Centre C", code="CENTRE_C", centre_type="PRIVATE_SUB", latitude=13.2000, longitude=77.5000, district="Hassan", state="KA", total_counters=2)
        
        db.add_all([c_a, c_b, c_c])
        db.commit()

        # Add heavy queue entries to Centre A
        for i in range(15):
            q = QueueEntry(booking_id=100 + i, centre_id=c_a.id, position=i+1, status="WAITING")
            db.add(q)
        db.commit()

    finally:
        db.close()

    # Call GET /centres near Mandya (12.5218, 76.8951)
    res = client.get("/centres?lat=12.5218&lng=76.8951")
    assert res.status_code == 200
    data = res.json()
    assert len(data) >= 3

    # Extract names in returned ranking order
    ranked_names = [item["name"] for item in data if item["name"] in ["Centre A", "Centre B", "Centre C"]]

    # Centre B must rank BEFORE Centre A because Centre A has 15 waiting farmers and only 1 counter,
    # proving the ranking function is multi-factor (distance + wait time + queue) and not nearest-only!
    assert ranked_names.index("Centre B") < ranked_names.index("Centre A")
    assert ranked_names.index("Centre B") < ranked_names.index("Centre C")
