import os
import pytest
from fastapi.testclient import TestClient
from backend.app.main import app
from backend.app.database import Base
from ml_service.predictor import predict_wait, get_loaded_model
from ml_service.train import train_wait_time_model
from tests.conftest import test_engine

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_ai_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_mae_threshold():
    model_data = get_loaded_model()
    if not model_data:
        mae = train_wait_time_model()
    else:
        mae = model_data.get("mae", 15.0)

    assert mae < 20.0, f"Model MAE {mae} exceeded threshold of 20 minutes"

def test_fallback_when_centre_history_count_is_zero():
    features = {
        "farmers_ahead": 10,
        "average_processing_time": 15.0,
        "active_counters": 2
    }
    result = predict_wait(features, centre_history_count=0)

    assert result["blend_weight_model"] == 0.0
    assert result["rule_estimate"] == 75.0
    assert result["predicted_wait_minutes"] == 75.0

def test_output_clamping_on_extreme_inputs():
    low_features = {"farmers_ahead": -10, "average_processing_time": -5.0, "active_counters": 1}
    low_res = predict_wait(low_features, centre_history_count=10)
    assert low_res["predicted_wait_minutes"] >= 2.0

    high_features = {"farmers_ahead": 1000, "average_processing_time": 100.0, "active_counters": 1}
    high_res = predict_wait(high_features, centre_history_count=10)
    assert high_res["predicted_wait_minutes"] <= 300.0

def test_predictions_api_endpoint():
    payload = {
        "centre_id": 1,
        "quantity": 25.0,
        "farmers_ahead": 4,
        "active_counters": 2,
        "average_processing_time": 12.0
    }
    res = client.post("/predictions/waiting-time", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert "predicted_wait_minutes" in data
    assert "confidence_score" in data
    assert data["predicted_wait_minutes"] > 0.0
