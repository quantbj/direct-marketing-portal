from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_create_contract():
    """Test creating a new contract."""
    response = client.post(
        "/contracts",
        json={
            "customer_name": "John Doe",
            "customer_email": "john@example.com",
            "doc_version": "1.0",
        },
    )
    assert response.status_code == 201
    data = response.json()
    assert data["customer_name"] == "John Doe"
    assert data["customer_email"] == "john@example.com"
    assert data["status"] == "draft"
    assert data["doc_version"] == "1.0"
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


def test_get_contract():
    """Test getting a contract by ID."""
    # Create a contract first
    create_response = client.post(
        "/contracts",
        json={
            "customer_name": "Jane Doe",
            "customer_email": "jane@example.com",
        },
    )
    contract_id = create_response.json()["id"]

    # Get the contract
    response = client.get(f"/contracts/{contract_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == contract_id
    assert data["customer_name"] == "Jane Doe"
    assert data["customer_email"] == "jane@example.com"


def test_get_contract_not_found():
    """Test getting a non-existent contract."""
    response = client.get("/contracts/999999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Contract not found"


def test_list_contracts():
    """Test listing all contracts."""
    # Create some contracts
    client.post(
        "/contracts",
        json={
            "customer_name": "Alice",
            "customer_email": "alice@example.com",
        },
    )
    client.post(
        "/contracts",
        json={
            "customer_name": "Bob",
            "customer_email": "bob@example.com",
        },
    )

    # List contracts
    response = client.get("/contracts")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    assert len(data) >= 2
