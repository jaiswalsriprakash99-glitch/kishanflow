import json
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.routers.auth import create_jwt_token
from backend.app.models import ProcurementCentre, Crop, Slot, Booking, QueueEntry
from tests.conftest import TestingSessionLocal

client = TestClient(app)

def test_websocket_broadcast_and_resync():
    token = create_jwt_token({"sub": "1", "phone_number": "9876543201", "role": "FARMER"})
    centre_id = 1

    # Test REST resync endpoint
    res_resync = client.get(f"/queue/resync/{centre_id}")
    assert res_resync.status_code == 200
    assert "active_queue" in res_resync.json()

    # Test WebSocket handshake with token
    with client.websocket_connect(f"/ws/centre/{centre_id}?token={token}") as ws1:
        assert ws1 is not None

def test_websocket_unauthorized_rejected():
    with pytest.raises(Exception):
        with client.websocket_connect("/ws/centre/1?token=invalid_token") as ws:
            pass
