import uuid

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_solar_contract():
    """Test creating a new solar contract."""
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
            "solar_direction": 180,
            "solar_inclination": 35,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["technology"] == "solar"
    assert data["nominal_capacity"] == 100.5
    assert data["solar_direction"] == 180
    assert data["solar_inclination"] == 35
    assert data["wind_turbine_height"] is None
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


def test_create_wind_contract():
    """Test creating a new wind contract."""
    response = client.post(
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
            "wind_turbine_height": 120.5,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["technology"] == "wind"
    assert data["wind_turbine_height"] == 120.5
    assert data["solar_direction"] is None
    assert data["solar_inclination"] is None


def test_create_contract_invalid_latitude():
    """Test creating a contract with invalid latitude."""
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 100.0,  # Invalid: > 90
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "solar",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
        },
    )
    assert response.status_code == 422


def test_create_contract_invalid_capacity():
    """Test creating a contract with invalid capacity."""
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "solar",
            "nominal_capacity": -10.0,  # Invalid: negative
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
        },
    )
    assert response.status_code == 422


def test_create_contract_invalid_dates():
    """Test creating a contract with end_date before start_date."""
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-12-31",
            "end_date": "2024-01-01",  # Before start_date
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "solar",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
        },
    )
    assert response.status_code == 422


def test_get_contract():
    """Test getting a contract by ID."""
    # Create a contract first
    create_response = client.post(
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
        },
    )
    contract_id = create_response.json()["id"]

    # Get the contract
    response = client.get(f"/contracts/{contract_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == contract_id
    assert data["technology"] == "solar"


def test_get_contract_not_found():
    """Test getting a non-existent contract."""
    random_uuid = str(uuid.uuid4())
    response = client.get(f"/contracts/{random_uuid}")
    assert response.status_code == 404
    assert response.json()["detail"] == "Contract not found"


def test_list_contracts():
    """Test listing all contracts."""
    # Create some contracts
    client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 111111,
            "technology": "solar",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
        },
    )
    client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 52.0,
            "location_lon": 5.0,
            "nab": 222222,
            "technology": "wind",
            "nominal_capacity": 250.0,
            "indexation": "month_ahead",
            "quantity_type": "pay_as_forecasted",
        },
    )

    # List contracts
    response = client.get("/contracts")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 2


def test_list_contracts_pagination():
    """Test pagination for contracts list."""
    # Create multiple contracts
    for i in range(5):
        client.post(
            "/contracts",
            json={
                "start_date": "2024-01-01",
                "end_date": "2024-12-31",
                "location_lat": 51.5 + i * 0.1,
                "location_lon": 4.3 + i * 0.1,
                "nab": 100000 + i,
                "technology": "solar",
                "nominal_capacity": 100.0 + i * 10,
                "indexation": "day_ahead",
                "quantity_type": "pay_as_produced",
            },
        )

    # Test limit parameter
    response = client.get("/contracts?limit=2")
    assert response.status_code == 200
    data = response.json()
    assert len(data) <= 2

    # Test skip parameter
    response = client.get("/contracts?skip=3")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
