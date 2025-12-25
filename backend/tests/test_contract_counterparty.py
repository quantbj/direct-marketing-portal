from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_contract_requires_counterparty_id():
    """Test that creating a contract requires a counterparty_id."""
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "solar",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
            # Missing counterparty_id
        },
    )
    assert response.status_code == 422


def test_create_contract_with_counterparty_success():
    """Test creating a contract with a valid counterparty."""
    # Create a counterparty first
    counterparty_response = client.post(
        "/counterparties",
        json={
            "type": "company",
            "name": "Energy Company",
            "street": "Power Street 100",
            "postal_code": "10115",
            "city": "Berlin",
            "country": "DE",
            "email": "energy@company.com",
        },
    )
    counterparty_id = counterparty_response.json()["id"]

    # Create a contract with the counterparty
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 52.52,
            "location_lon": 13.405,
            "nab": 999888,
            "technology": "wind",
            "nominal_capacity": 500.0,
            "indexation": "month_ahead",
            "quantity_type": "pay_as_forecasted",
            "counterparty_id": counterparty_id,
            "wind_turbine_height": 150.0,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["counterparty_id"] == counterparty_id
    assert data["technology"] == "wind"
    assert "id" in data


def test_create_contract_with_nonexistent_counterparty():
    """Test that creating a contract with non-existent counterparty fails."""
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "solar",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
            "counterparty_id": 99999,  # Non-existent counterparty
        },
    )
    assert response.status_code == 404
    assert "not found" in response.json()["detail"]
