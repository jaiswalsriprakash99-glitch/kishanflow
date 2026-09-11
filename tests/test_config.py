import pytest
from fastapi.testclient import TestClient
from backend.app.config import Settings, get_settings
from backend.app.main import app

def test_missing_database_url_raises_error():
    with pytest.raises(ValueError) as exc_info:
        get_settings(override_env={"JWT_SECRET": "secret_key"})
    assert "DATABASE_URL environment variable is missing or empty" in str(exc_info.value)

def test_valid_database_url_config():
    settings = get_settings(override_env={"DATABASE_URL": "sqlite:///:memory:", "JWT_SECRET": "test_secret"})
    assert settings.DATABASE_URL == "sqlite:///:memory:"
    assert settings.JWT_SECRET == "test_secret"

def test_health_check_db_connectivity():
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["database"] == "connected"
