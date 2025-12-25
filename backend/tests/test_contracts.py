import uuid

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def create_test_counterparty():
    """Helper function to create a test counterparty."""
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Test Counterparty",
            "street": "Test Street 1",
            "postal_code": "12345",
            "city": "Test City",
            "country": "DE",
            "email": f"test{uuid.uuid4().hex[:8]}@example.com",
        },
    )
    return response.json()["id"]


def get_test_offer_id():
    """Helper function to get a valid offer ID."""
    response = client.get("/offers")
    offers = response.json()
    return offers[0]["id"] if offers else None


def test_create_solar_contract():
    """Test creating a new solar contract."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
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
    assert data["counterparty_id"] == counterparty_id
    assert data["offer_id"] == offer_id
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


def test_create_wind_contract():
    """Test creating a new wind contract."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
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
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    assert response.status_code == 422


def test_create_contract_invalid_capacity():
    """Test creating a contract with invalid capacity."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    assert response.status_code == 422


def test_create_contract_invalid_dates():
    """Test creating a contract with end_date before start_date."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    assert response.status_code == 422


def test_get_contract():
    """Test getting a contract by ID."""
    # Create a contract first
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
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
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
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
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
    # Use small increments to ensure all contracts have valid lat/lon within acceptable ranges
    for i in range(5):
        client.post(
            "/contracts",
            json={
                "start_date": "2024-01-01",
                "end_date": "2024-12-31",
                "location_lat": 51.0 + i * 0.01,  # 51.00 to 51.04, within valid range
                "location_lon": 4.0 + i * 0.01,  # 4.00 to 4.04, within valid range
                "nab": 100000 + i,
                "technology": "solar",
                "nominal_capacity": 100.0 + i * 10,  # Increment capacity by 10 kW per contract
                "indexation": "day_ahead",
                "quantity_type": "pay_as_produced",
                "counterparty_id": counterparty_id,
                "offer_id": offer_id,
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


def test_create_contract_solar_field_on_wind():
    """Test that solar fields cannot be provided for wind technology."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-12-31",
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "wind",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
            "solar_direction": 180,  # Invalid for wind
        },
    )
    assert response.status_code == 422


def test_create_contract_wind_field_on_solar():
    """Test that wind fields cannot be provided for solar technology."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
            "wind_turbine_height": 120.5,  # Invalid for solar
        },
    )
    assert response.status_code == 422


def test_create_contract_equal_dates():
    """Test that start_date and end_date cannot be equal."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
    response = client.post(
        "/contracts",
        json={
            "start_date": "2024-01-01",
            "end_date": "2024-01-01",  # Same as start_date
            "location_lat": 51.5,
            "location_lon": 4.3,
            "nab": 123456,
            "technology": "solar",
            "nominal_capacity": 100.5,
            "indexation": "day_ahead",
            "quantity_type": "pay_as_produced",
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    assert response.status_code == 422


def test_create_contract_invalid_solar_direction():
    """Test that solar direction must be between 0 and 359 degrees."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
            "solar_direction": 360,  # Invalid: >= 360
        },
    )
    assert response.status_code == 422


def test_create_contract_invalid_solar_inclination():
    """Test that solar inclination must be between 0 and 90 degrees."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
            "solar_inclination": 100,  # Invalid: > 90
        },
    )
    assert response.status_code == 422


def test_create_contract_requires_offer_id():
    """Test that creating a contract requires offer_id."""
    counterparty_id = create_test_counterparty()
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
            "counterparty_id": counterparty_id,
            # Missing offer_id
        },
    )
    assert response.status_code == 422


def test_create_contract_rejects_missing_offer():
    """Test that creating a contract with non-existent offer fails."""
    counterparty_id = create_test_counterparty()
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
            "counterparty_id": counterparty_id,
            "offer_id": 999999,  # Non-existent offer
        },
    )
    assert response.status_code == 422
    assert "Offer not found" in response.json()["detail"]


def test_create_contract_with_valid_offer_success():
    """Test creating a contract with a valid active offer."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()
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
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
            "solar_direction": 180,
            "solar_inclination": 35,
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["offer_id"] == offer_id
    assert data["counterparty_id"] == counterparty_id
