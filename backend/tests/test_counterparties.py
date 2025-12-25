from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_counterparty_success():
    """Test creating a new counterparty."""
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "John Doe",
            "street": "Main St 123",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "DE",
            "email": "john.doe@example.com",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "John Doe"
    assert data["email"] == "john.doe@example.com"
    assert data["type"] == "person"
    assert data["country"] == "DE"
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


def test_create_counterparty_company():
    """Test creating a company counterparty."""
    response = client.post(
        "/counterparties",
        json={
            "type": "company",
            "name": "ACME Corp",
            "street": "Business Ave 456",
            "postal_code": "54321",
            "city": "Munich",
            "country": "DE",
            "email": "contact@acme.com",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["type"] == "company"
    assert data["name"] == "ACME Corp"


def test_get_counterparty_success():
    """Test getting a counterparty by ID."""
    # Create a counterparty first
    create_response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Jane Smith",
            "street": "Oak Street 789",
            "postal_code": "67890",
            "city": "Hamburg",
            "country": "DE",
            "email": "jane.smith@example.com",
        },
    )
    counterparty_id = create_response.json()["id"]

    # Get the counterparty
    response = client.get(f"/counterparties/{counterparty_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == counterparty_id
    assert data["name"] == "Jane Smith"
    assert data["email"] == "jane.smith@example.com"


def test_get_counterparty_not_found():
    """Test getting a non-existent counterparty."""
    response = client.get("/counterparties/999999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Counterparty not found"


def test_create_counterparty_invalid_email():
    """Test creating a counterparty with invalid email."""
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Invalid Email",
            "street": "Test St",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "DE",
            "email": "not-an-email",
        },
    )
    assert response.status_code == 422


def test_create_counterparty_invalid_country():
    """Test creating a counterparty with invalid country code."""
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Invalid Country",
            "street": "Test St",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "Germany",  # Should be 2-letter uppercase
            "email": "test@example.com",
        },
    )
    assert response.status_code == 422


def test_create_counterparty_invalid_type():
    """Test creating a counterparty with invalid type."""
    response = client.post(
        "/counterparties",
        json={
            "type": "invalid",
            "name": "Invalid Type",
            "street": "Test St",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "DE",
            "email": "test@example.com",
        },
    )
    assert response.status_code == 422


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


def test_create_contract_with_counterparty_success():
    """Test creating a contract with a valid counterparty."""
    # Create a counterparty first
    counterparty_response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Contract Owner",
            "street": "Energy St 100",
            "postal_code": "11111",
            "city": "Amsterdam",
            "country": "NL",
            "email": "owner@example.com",
        },
    )
    counterparty_id = counterparty_response.json()["id"]

    # Create a contract with the counterparty
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
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["counterparty_id"] == counterparty_id
    assert data["technology"] == "solar"


def test_create_contract_with_invalid_counterparty_id():
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
            "counterparty_id": 999999,
        },
    )
    assert response.status_code == 404
    assert response.json()["detail"] == "Counterparty not found"
