"""E-signature provider abstraction and implementations."""

import hmac
import uuid
from typing import Protocol

from fastapi import Request

from app.core.config import settings


class ESignProvider(Protocol):
    """Protocol for e-signature provider implementations."""

    def create_envelope(self, contract_id: uuid.UUID, draft_pdf_path: str) -> dict:
        """
        Create a signing envelope for a contract.

        Args:
            contract_id: UUID of the contract
            draft_pdf_path: Relative path to the draft PDF

        Returns:
            dict with keys:
                - provider_envelope_id: Stable external ID
                - signing_url: URL for user to sign
        """
        ...

    async def parse_webhook(self, request: Request) -> dict:
        """
        Parse webhook payload from the provider.

        Args:
            request: FastAPI Request object

        Returns:
            dict with keys:
                - provider_envelope_id: Stable external ID
                - event_type: Type of event (e.g., "signed", "declined", "voided")
                - payload: Raw payload data
        """
        ...


class StubESignProvider:
    """Stub implementation of e-signature provider for testing."""

    def create_envelope(self, contract_id: uuid.UUID, draft_pdf_path: str) -> dict:
        """
        Create a stub signing envelope.

        Args:
            contract_id: UUID of the contract
            draft_pdf_path: Relative path to the draft PDF

        Returns:
            dict with provider_envelope_id and signing_url
        """
        envelope_id = str(uuid.uuid4())
        return {
            "provider_envelope_id": envelope_id,
            "signing_url": f"https://example.invalid/sign/{envelope_id}",
        }

    async def parse_webhook(self, request: Request) -> dict:
        """
        Parse stub webhook payload.

        Expected JSON format:
        {
            "envelope_id": "provider_envelope_id",
            "event": "signed" | "declined" | "voided"
        }

        Args:
            request: FastAPI Request object

        Returns:
            dict with provider_envelope_id, event_type, and payload
        """
        # Get raw body first (before it's consumed by json parsing)
        body = await request.body()

        # Verify HMAC signature unless skipped
        if not settings.ESIGN_SKIP_WEBHOOK_SIGNATURE:
            await self._verify_signature(request, body)

        # Parse JSON payload
        import json

        payload = json.loads(body)
        return {
            "provider_envelope_id": payload["envelope_id"],
            "event_type": payload["event"],
            "payload": payload,
        }

    async def _verify_signature(self, request: Request, body: bytes) -> None:
        """
        Verify HMAC signature of webhook request.

        Args:
            request: FastAPI Request object
            body: Raw request body bytes

        Raises:
            ValueError: If signature is missing or invalid
        """
        # Get signature from header
        signature_header = request.headers.get("X-ESign-Signature", "")
        if not signature_header.startswith("sha256="):
            raise ValueError("Missing or invalid signature header")

        provided_signature = signature_header[7:]  # Remove 'sha256=' prefix

        # Calculate expected signature
        secret = settings.ESIGN_WEBHOOK_SECRET.encode("utf-8")
        expected_signature = hmac.new(secret, body, "sha256").hexdigest()

        # Compare signatures (timing-safe)
        if not hmac.compare_digest(provided_signature, expected_signature):
            raise ValueError("Invalid signature")


def get_esign_provider() -> ESignProvider:
    """
    Get the configured e-signature provider instance.

    Returns:
        ESignProvider instance
    """
    if settings.ESIGN_PROVIDER == "stub":
        return StubESignProvider()
    else:
        raise ValueError(f"Unknown e-signature provider: {settings.ESIGN_PROVIDER}")
