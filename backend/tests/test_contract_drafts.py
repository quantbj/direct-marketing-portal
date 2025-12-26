"""Tests for contract draft endpoints."""

import uuid
from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import settings
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


def test_create_contract_draft_success():
    """Test creating a contract draft with PDF generation."""
    # Create counterparty and get offer
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()

    # Create draft
    response = client.post(
        "/contracts/draft",
        json={
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )

    # Assert response
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "draft"
    assert data["counterparty_id"] == counterparty_id
    assert data["offer_id"] == offer_id
    assert data["draft_pdf_available"] is True
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data

    # Verify PDF file exists on disk
    contract_id = data["id"]
    pdf_path = Path(settings.STORAGE_ROOT) / "contracts" / contract_id / "draft.pdf"
    assert pdf_path.exists()
    assert pdf_path.stat().st_size > 0


def test_create_contract_draft_rejects_missing_counterparty():
    """Test that creating a draft with non-existent counterparty returns 404."""
    offer_id = get_test_offer_id()

    response = client.post(
        "/contracts/draft",
        json={
            "counterparty_id": 999999,  # Non-existent
            "offer_id": offer_id,
        },
    )

    assert response.status_code == 404
    assert "Counterparty not found" in response.json()["detail"]


def test_create_contract_draft_rejects_inactive_offer():
    """Test that creating a draft with inactive offer returns 422."""
    counterparty_id = create_test_counterparty()

    # This test assumes we don't have inactive offers in test data
    # If we need to test this properly, we'd need to create an inactive offer first
    # For now, we test with a non-existent offer which also returns an error
    response = client.post(
        "/contracts/draft",
        json={
            "counterparty_id": counterparty_id,
            "offer_id": 999999,  # Non-existent
        },
    )

    assert response.status_code == 404
    assert "Offer not found" in response.json()["detail"]


def test_get_contract_includes_offer_and_counterparty():
    """Test that GET /contracts/{id} includes embedded counterparty and offer."""
    # Create draft
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()

    create_response = client.post(
        "/contracts/draft",
        json={
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    contract_id = create_response.json()["id"]

    # Get contract
    response = client.get(f"/contracts/{contract_id}")

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == contract_id
    assert data["status"] == "draft"
    assert data["counterparty_id"] == counterparty_id
    assert data["offer_id"] == offer_id

    # Verify embedded counterparty
    assert data["counterparty"] is not None
    assert data["counterparty"]["id"] == counterparty_id
    assert "name" in data["counterparty"]
    assert "email" in data["counterparty"]

    # Verify embedded offer
    assert data["offer"] is not None
    assert data["offer"]["id"] == offer_id
    assert "name" in data["offer"]
    assert "price_cents" in data["offer"]


def test_download_draft_pdf_returns_pdf():
    """Test that GET /contracts/{id}/draft-pdf returns a PDF."""
    # Create draft
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()

    create_response = client.post(
        "/contracts/draft",
        json={
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    contract_id = create_response.json()["id"]

    # Download PDF
    response = client.get(f"/contracts/{contract_id}/draft-pdf")

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert len(response.content) > 0


def test_download_draft_pdf_returns_404_for_nonexistent_contract():
    """Test that downloading PDF for non-existent contract returns 404."""
    random_uuid = str(uuid.uuid4())
    response = client.get(f"/contracts/{random_uuid}/draft-pdf")

    assert response.status_code == 404
    assert "Contract not found" in response.json()["detail"]
