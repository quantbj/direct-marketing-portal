"""Tests for offers API endpoints."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_list_offers_returns_seeded_offers():
    """Test that GET /offers returns the seeded offers."""
    response = client.get("/offers")
    assert response.status_code == 200
    data = response.json()
    assert isinstance(data, list)
    # Should have at least 5 seeded offers
    assert len(data) >= 5
    # Verify they're sorted by price
    prices = [offer["price_cents"] for offer in data]
    assert prices == sorted(prices)
    # Check all are active
    for offer in data:
        assert offer["is_active"] is True


def test_list_offers_contains_expected_codes():
    """Test that the seeded offers have the expected codes."""
    response = client.get("/offers")
    assert response.status_code == 200
    data = response.json()
    codes = {offer["code"] for offer in data}
    # Check that all expected codes are present
    expected_codes = {"STARTER", "BASIC", "PRO", "PREMIUM", "ENTERPRISE"}
    assert expected_codes.issubset(codes)


def test_get_offer_by_id_success():
    """Test getting a specific offer by ID."""
    # First get the list to get a valid ID
    list_response = client.get("/offers")
    offers = list_response.json()
    assert len(offers) > 0

    # Get the first offer by ID
    offer_id = offers[0]["id"]
    response = client.get(f"/offers/{offer_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == offer_id
    assert "code" in data
    assert "name" in data
    assert "price_cents" in data
    assert "currency" in data
    assert "billing_period" in data
    assert "is_active" in data


def test_get_offer_not_found():
    """Test getting a non-existent offer returns 404."""
    response = client.get("/offers/999999")
    assert response.status_code == 404
    assert response.json()["detail"] == "Offer not found"


def test_offer_response_has_all_fields():
    """Test that offer responses include all required fields."""
    response = client.get("/offers")
    assert response.status_code == 200
    offers = response.json()
    assert len(offers) > 0

    offer = offers[0]
    required_fields = [
        "id",
        "code",
        "name",
        "description",
        "currency",
        "price_cents",
        "billing_period",
        "min_term_months",
        "notice_period_days",
        "is_active",
        "created_at",
        "updated_at",
    ]
    for field in required_fields:
        assert field in offer
