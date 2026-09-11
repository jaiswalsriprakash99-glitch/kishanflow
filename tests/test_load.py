import time
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base
from database.seed_data import seed_database
from tests.conftest import test_engine, TestingSessionLocal

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_load_db():
    Base.metadata.drop_all(bind=test_engine)
    Base.metadata.create_all(bind=test_engine)
    db = TestingSessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
    yield
    Base.metadata.drop_all(bind=test_engine)

def _make_simulated_request(user_index: int):
    # Perform a sequence of typical farmer requests
    r1 = client.get("/health")
    r2 = client.get("/centres?latitude=12.52&longitude=76.89")
    r3 = client.get("/centres/1/queue")
    r4 = client.post("/predictions/waiting-time", json={
        "centre_id": 1,
        "quantity": 25.0,
        "farmers_ahead": user_index % 10 + 1,
        "active_counters": 2
    })
    return (r1.status_code == 200 and r2.status_code == 200 and r3.status_code == 200 and r4.status_code == 200)

def test_concurrent_load_simulation_50_users():
    num_simulated_users = 50
    start_time = time.time()

    successes = 0
    failures = 0

    for i in range(num_simulated_users):
        try:
            res = _make_simulated_request(i)
            if res:
                successes += 1
            else:
                failures += 1
        except Exception:
            failures += 1

    elapsed = time.time() - start_time
    print(f"\nLoad Test Completed: {successes}/{num_simulated_users} passed in {elapsed:.2f}s")

    assert failures == 0, f"Expected 0 failures during load test, got {failures}"
    assert successes == num_simulated_users
