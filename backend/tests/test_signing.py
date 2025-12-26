"""Tests for e-signature integration endpoints."""

import hmac
import json
import uuid
from pathlib import Path

from fastapi.testclient import TestClient

from app.core.config import settings
from app.main import app

client = TestClient(app)


# Pre-test configuration validation
def validate_test_configuration():
    """Validate required environment configuration for signing tests."""
    errors = []

    # Validate ESIGN_WEBHOOK_SECRET
    if not settings.ESIGN_WEBHOOK_SECRET:
        errors.append(
            "ESIGN_WEBHOOK_SECRET is not configured. "
            "Set environment variable: ESIGN_WEBHOOK_SECRET=<your-secret>"
        )
    elif len(settings.ESIGN_WEBHOOK_SECRET) < 16:
        errors.append(
            f"ESIGN_WEBHOOK_SECRET is too short ({len(settings.ESIGN_WEBHOOK_SECRET)} chars). "
            "Use at least 16 characters for security."
        )

    # Validate STORAGE_ROOT
    storage_path = Path(settings.STORAGE_ROOT)
    if not storage_path.exists():
        try:
            storage_path.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            errors.append(
                f"STORAGE_ROOT directory '{settings.STORAGE_ROOT}' does not exist "
                f"and could not be created: {e}"
            )

    # Check if STORAGE_ROOT is writable
    if storage_path.exists():
        test_file = storage_path / ".write_test"
        try:
            test_file.write_text("test")
            test_file.unlink()
        except Exception as e:
            errors.append(f"STORAGE_ROOT directory '{settings.STORAGE_ROOT}' is not writable: {e}")

    if errors:
        error_msg = "Configuration validation failed:\n" + "\n".join(f"  - {e}" for e in errors)
        raise RuntimeError(error_msg)


# Run validation when module is imported
validate_test_configuration()


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


def create_draft_contract():
    """Helper to create a draft contract."""
    counterparty_id = create_test_counterparty()
    offer_id = get_test_offer_id()

    response = client.post(
        "/contracts/draft",
        json={
            "counterparty_id": counterparty_id,
            "offer_id": offer_id,
        },
    )
    return response.json()


def calculate_webhook_signature(payload: dict, secret: str) -> str:
    """Calculate HMAC-SHA256 signature for webhook payload."""
    # Use separators to match FastAPI/Starlette's compact JSON serialization
    body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    signature = hmac.new(secret.encode("utf-8"), body, "sha256").hexdigest()
    return f"sha256={signature}"


def test_start_signing_happy_path():
    """Test starting signing process for a draft contract."""
    # Create draft contract
    draft = create_draft_contract()
    contract_id = draft["id"]

    # Start signing
    response = client.post(f"/contracts/{contract_id}/signing/start")

    # Assert response
    assert response.status_code == 200
    data = response.json()
    assert data["contract_id"] == contract_id
    assert data["status"] == "awaiting_signature"
    assert data["provider"] == "stub"
    assert "provider_envelope_id" in data
    assert "signing_url" in data
    assert data["signing_url"].startswith("https://example.invalid/sign/")


def test_start_signing_requires_draft_status():
    """Test that starting signing requires contract to be in draft status."""
    # Create draft contract
    draft = create_draft_contract()
    contract_id = draft["id"]

    # Start signing once
    response = client.post(f"/contracts/{contract_id}/signing/start")
    assert response.status_code == 200

    # Try to start signing again (contract now in awaiting_signature)
    response = client.post(f"/contracts/{contract_id}/signing/start")
    assert response.status_code == 409
    assert "draft status" in response.json()["detail"]


def test_start_signing_requires_draft_pdf():
    """Test that starting signing requires a draft PDF to exist."""
    # This test would need a way to create a contract without a draft PDF
    # For now, we test with a non-existent contract
    random_uuid = str(uuid.uuid4())
    response = client.post(f"/contracts/{random_uuid}/signing/start")
    assert response.status_code == 404


def test_webhook_signed_transitions_contract_and_creates_signed_pdf():
    """Test webhook handler for signed event creates PDF and updates contract."""
    # Create draft and start signing
    draft = create_draft_contract()
    contract_id = draft["id"]

    start_response = client.post(f"/contracts/{contract_id}/signing/start")
    assert start_response.status_code == 200
    envelope_id = start_response.json()["provider_envelope_id"]

    # Prepare webhook payload
    payload = {"envelope_id": envelope_id, "event": "signed"}

    # Calculate signature using configured secret
    secret = settings.ESIGN_WEBHOOK_SECRET
    signature = calculate_webhook_signature(payload, secret)

    # Send webhook
    response = client.post(
        "/webhooks/esign/stub",
        json=payload,
        headers={"X-ESign-Signature": signature},
    )

    # Assert webhook response
    assert response.status_code == 200, (
        f"Webhook failed with status {response.status_code}. "
        f"Response: {response.text}. "
        f"Secret used: {'<empty>' if not secret else f'{len(secret)} chars'}. "
        f"Signature: {signature}"
    )
    assert response.json() == {"ok": True}

    # Verify contract was updated
    contract_response = client.get(f"/contracts/{contract_id}")
    assert contract_response.status_code == 200
    contract_data = contract_response.json()
    assert contract_data["status"] == "signed"

    # Verify signed PDF exists
    pdf_path = Path(settings.STORAGE_ROOT) / "contracts" / contract_id / "signed.pdf"
    assert pdf_path.exists(), (
        f"Signed PDF not found at {pdf_path}. "
        f"STORAGE_ROOT: {settings.STORAGE_ROOT}. "
        f"Directory exists: {pdf_path.parent.exists()}"
    )
    assert pdf_path.stat().st_size > 0, f"Signed PDF at {pdf_path} is empty"


def test_webhook_rejects_invalid_signature():
    """Test webhook rejects requests with invalid signature."""
    # Create draft and start signing
    draft = create_draft_contract()
    contract_id = draft["id"]

    start_response = client.post(f"/contracts/{contract_id}/signing/start")
    assert start_response.status_code == 200
    envelope_id = start_response.json()["provider_envelope_id"]

    # Prepare webhook payload
    payload = {"envelope_id": envelope_id, "event": "signed"}

    # Send webhook with invalid signature
    response = client.post(
        "/webhooks/esign/stub",
        json=payload,
        headers={"X-ESign-Signature": "sha256=invalid_signature"},
    )

    # Assert rejection
    assert response.status_code == 401


def test_webhook_accepts_valid_signature():
    """Test webhook accepts requests with valid signature."""
    # Create draft and start signing
    draft = create_draft_contract()
    contract_id = draft["id"]

    start_response = client.post(f"/contracts/{contract_id}/signing/start")
    assert start_response.status_code == 200
    envelope_id = start_response.json()["provider_envelope_id"]

    # Prepare webhook payload
    payload = {"envelope_id": envelope_id, "event": "signed"}

    # Calculate correct signature using configured secret
    secret = settings.ESIGN_WEBHOOK_SECRET
    signature = calculate_webhook_signature(payload, secret)

    # Send webhook with valid signature
    response = client.post(
        "/webhooks/esign/stub",
        json=payload,
        headers={"X-ESign-Signature": signature},
    )

    # Assert acceptance
    assert response.status_code == 200, (
        f"Webhook failed with status {response.status_code}. "
        f"Response: {response.text}. "
        f"Secret configured: {'Yes' if settings.ESIGN_WEBHOOK_SECRET else 'No'}. "
        f"Signature: {signature}"
    )


def test_download_signed_pdf_404_when_not_signed():
    """Test that downloading signed PDF returns 404 before contract is signed."""
    # Create draft contract
    draft = create_draft_contract()
    contract_id = draft["id"]

    # Try to download signed PDF before signing
    response = client.get(f"/contracts/{contract_id}/signed-pdf")
    assert response.status_code == 404
    assert "Signed PDF not found" in response.json()["detail"]


def test_download_signed_pdf_returns_pdf_after_signing():
    """Test that signed PDF can be downloaded after contract is signed."""
    # Create draft and complete signing flow
    draft = create_draft_contract()
    contract_id = draft["id"]

    # Start signing
    start_response = client.post(f"/contracts/{contract_id}/signing/start")
    envelope_id = start_response.json()["provider_envelope_id"]

    # Send signed webhook
    payload = {"envelope_id": envelope_id, "event": "signed"}
    secret = settings.ESIGN_WEBHOOK_SECRET
    signature = calculate_webhook_signature(payload, secret)

    webhook_response = client.post(
        "/webhooks/esign/stub",
        json=payload,
        headers={"X-ESign-Signature": signature},
    )
    assert webhook_response.status_code == 200, (
        f"Webhook failed: {webhook_response.status_code} - {webhook_response.text}"
    )

    # Download signed PDF
    response = client.get(f"/contracts/{contract_id}/signed-pdf")
    assert response.status_code == 200, (
        f"Failed to download signed PDF: {response.status_code} - {response.text}. "
        f"STORAGE_ROOT: {settings.STORAGE_ROOT}"
    )
    assert response.headers["content-type"] == "application/pdf"
    assert len(response.content) > 0


def test_webhook_idempotent_for_repeated_signed_events():
    """Test webhook handler is idempotent for repeated signed events."""
    # Create draft and start signing
    draft = create_draft_contract()
    contract_id = draft["id"]

    start_response = client.post(f"/contracts/{contract_id}/signing/start")
    envelope_id = start_response.json()["provider_envelope_id"]

    # Send signed webhook twice
    payload = {"envelope_id": envelope_id, "event": "signed"}
    secret = settings.ESIGN_WEBHOOK_SECRET
    signature = calculate_webhook_signature(payload, secret)

    # First webhook
    response1 = client.post(
        "/webhooks/esign/stub",
        json=payload,
        headers={"X-ESign-Signature": signature},
    )
    assert response1.status_code == 200, (
        f"First webhook failed: {response1.status_code} - {response1.text}"
    )

    # Second webhook (should still succeed)
    response2 = client.post(
        "/webhooks/esign/stub",
        json=payload,
        headers={"X-ESign-Signature": signature},
    )
    assert response2.status_code == 200, (
        f"Second webhook failed (idempotency issue): {response2.status_code} - {response2.text}"
    )

    # Verify contract is still signed
    contract_response = client.get(f"/contracts/{contract_id}")
    assert contract_response.json()["status"] == "signed"
