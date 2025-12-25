from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_contract_requires_counterparty_id():
    """Test that creating a contract requires counterparty_id."""
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


def test_create_contract_with_invalid_counterparty_id():
    """Test that creating a contract with invalid counterparty_id fails."""
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
            "counterparty_id": 999999,  # Non-existent counterparty
        },
    )
    assert response.status_code == 400
    assert "not found" in response.json()["detail"].lower()


def test_create_contract_with_counterparty_success():
    """Test creating a contract with a valid counterparty."""
    # First create a counterparty
    counterparty_response = client.post(
        "/counterparties",
        json={
            "name": "Solar Customer",
            "street": "Solar Street 1",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "DE",
            "email": "solar@example.com",
        },
    )
    assert counterparty_response.status_code == 201
    counterparty_id = counterparty_response.json()["id"]

    # Create a contract with this counterparty
    contract_response = client.post(
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
            "counterparty_id": counterparty_id,
        },
    )
    assert contract_response.status_code == 201
    contract_data = contract_response.json()
    assert contract_data["counterparty_id"] == counterparty_id
    assert contract_data["counterparty"] is not None
    assert contract_data["counterparty"]["id"] == counterparty_id
    assert contract_data["counterparty"]["name"] == "Solar Customer"


def test_get_contract_includes_counterparty():
    """Test that getting a contract includes counterparty information."""
    # Create counterparty
    counterparty_response = client.post(
        "/counterparties",
        json={
            "name": "Wind Customer",
            "street": "Wind Road 2",
            "postal_code": "54321",
            "city": "Hamburg",
            "country": "DE",
            "email": "wind@example.com",
        },
    )
    counterparty_id = counterparty_response.json()["id"]

    # Create contract
    create_response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 52.0,
            "location_lon": 5.0,
            "nab": 789012,
            "technology": "wind",
            "nominal_capacity": 250.0,
            "indexation": "month_ahead",
            "quantity_type": "pay_as_forecasted",
            "counterparty_id": counterparty_id,
        },
    )
    contract_id = create_response.json()["id"]

    # Get contract
    get_response = client.get(f"/contracts/{contract_id}")
    assert get_response.status_code == 200
    data = get_response.json()
    assert data["counterparty_id"] == counterparty_id
    assert data["counterparty"]["name"] == "Wind Customer"
