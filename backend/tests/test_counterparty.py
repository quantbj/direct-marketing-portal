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
    assert data["type"] == "person"
    assert data["country"] == "DE"
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


def test_get_counterparty_success():
    """Test getting a counterparty by ID."""
    # Create a counterparty first
    create_response = client.post(
        "/counterparties",
        json={
            "type": "company",
            "name": "Acme Corp",
            "street": "Industrial Park 1",
            "postal_code": "54321",
            "city": "Munich",
            "country": "DE",
            "email": "contact@acme.com",
        },
    )
    counterparty_id = create_response.json()["id"]

    # Get the counterparty
    response = client.get(f"/counterparties/{counterparty_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == counterparty_id
    assert data["name"] == "Acme Corp"
    assert data["type"] == "company"


def test_email_validation_rejects_invalid():
    """Test that invalid email addresses are rejected."""
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Jane Doe",
            "street": "Side Street 456",
            "postal_code": "67890",
            "city": "Hamburg",
            "country": "DE",
            "email": "not-an-email",  # Invalid email
        },
    )
    assert response.status_code == 422


def test_create_counterparty_duplicate_email_returns_409():
    """Test that creating a counterparty with duplicate email returns 409."""
    # Create first counterparty
    email = "duplicate@example.com"
    client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "First Person",
            "street": "First Street 1",
            "postal_code": "11111",
            "city": "Frankfurt",
            "country": "DE",
            "email": email,
        },
    )

    # Try to create another counterparty with the same email
    response = client.post(
        "/counterparties",
        json={
            "type": "person",
            "name": "Second Person",
            "street": "Second Street 2",
            "postal_code": "22222",
            "city": "Cologne",
            "country": "DE",
            "email": email,
        },
    )
    assert response.status_code == 409
    assert "already exists" in response.json()["detail"]
