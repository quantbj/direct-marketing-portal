from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"ok": True}


def test_db_health_success():
    response = client.get("/health/db")
    assert response.status_code == 200
    assert response.json() == {"ok": True}
