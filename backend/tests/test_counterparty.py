from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_counterparty_success():
    """Test creating a new counterparty successfully."""
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "John Doe",
            "street": "Main Street 123",
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
    assert data["country"] == "DE"
    assert data["type"] == "person"
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
            "street": "Business Blvd 456",
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
            "name": "Jane Smith",
            "street": "Oak Avenue 789",
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


def test_email_validation_rejects_invalid():
    """Test that invalid email addresses are rejected."""
    response = client.post(
        "/counterparties",
        json={
            "name": "Test User",
            "street": "Test Street 1",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "DE",
            "email": "not-a-valid-email",
        },
    )
    assert response.status_code == 422


def test_country_validation_rejects_invalid():
    """Test that invalid country codes are rejected."""
    response = client.post(
        "/counterparties",
        json={
            "name": "Test User",
            "street": "Test Street 1",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "Germany",  # Invalid: should be 2-letter code
            "email": "test@example.com",
        },
    )
    assert response.status_code == 422


def test_country_validation_lowercase_rejected():
    """Test that lowercase country codes are rejected."""
    response = client.post(
        "/counterparties",
        json={
            "name": "Test User",
            "street": "Test Street 1",
            "postal_code": "12345",
            "city": "Berlin",
            "country": "de",  # Invalid: should be uppercase
            "email": "test@example.com",
        },
    )
    assert response.status_code == 422
