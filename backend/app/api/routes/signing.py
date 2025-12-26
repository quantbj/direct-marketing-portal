"""E-signature API routes."""

import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException, Request
from sqlalchemy.orm import Session

from app.db.models.contract import Contract
from app.db.models.signature_envelope import SignatureEnvelope
from app.db.session import engine
from app.services.esign_provider import get_esign_provider
from app.services.pdf_service import generate_signed_pdf

router = APIRouter(tags=["signing"])


@router.post("/contracts/{contract_id}/signing/start")
def start_signing(contract_id: uuid.UUID):
    """
    Start the signing process for a contract.

    Creates a signature envelope and transitions the contract to awaiting_signature.
    """
    with Session(engine) as session:
        # Get contract with relationships
        contract = session.get(Contract, contract_id)
        if not contract:
            raise HTTPException(status_code=404, detail="Contract not found")

        # Verify contract is in draft status
        if contract.status != "draft":
            raise HTTPException(
                status_code=409,
                detail=f"Contract must be in draft status, currently: {contract.status}",
            )

        # Verify draft PDF exists
        if not contract.draft_pdf_path:
            raise HTTPException(status_code=409, detail="Contract must have a draft PDF")

        # Get e-sign provider
        provider = get_esign_provider()

        # Create envelope with provider
        envelope_data = provider.create_envelope(contract_id, contract.draft_pdf_path)

        # Create signature envelope record
        envelope = SignatureEnvelope(
            contract_id=contract_id,
            provider="stub",
            provider_envelope_id=envelope_data["provider_envelope_id"],
            status="sent",
            signing_url=envelope_data["signing_url"],
        )
        session.add(envelope)

        # Update contract status
        contract.status = "awaiting_signature"

        session.commit()
        session.refresh(envelope)

        return {
            "contract_id": str(contract_id),
            "status": contract.status,
            "provider": envelope.provider,
            "provider_envelope_id": envelope.provider_envelope_id,
            "signing_url": envelope.signing_url,
        }


@router.post("/webhooks/esign/{provider}")
async def esign_webhook(provider: str, request: Request):
    """
    Webhook receiver for e-signature provider events.

    Handles events like signed, declined, voided, etc.
    """
    if provider != "stub":
        raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")

    # Get provider instance
    esign_provider = get_esign_provider()

    # Parse webhook payload (includes signature verification)
    try:
        webhook_data = await esign_provider.parse_webhook(request)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))

    provider_envelope_id = webhook_data["provider_envelope_id"]
    event_type = webhook_data["event_type"]
    payload = webhook_data["payload"]

    with Session(engine) as session:
        # Find envelope
        envelope = (
            session.query(SignatureEnvelope)
            .filter(
                SignatureEnvelope.provider == provider,
                SignatureEnvelope.provider_envelope_id == provider_envelope_id,
            )
            .first()
        )

        if not envelope:
            raise HTTPException(
                status_code=404,
                detail=f"Envelope not found: {provider}:{provider_envelope_id}",
            )

        # Get contract
        contract = session.get(Contract, envelope.contract_id)
        if not contract:
            raise HTTPException(status_code=404, detail="Contract not found")

        # Update envelope
        envelope.status = event_type
        envelope.last_webhook_at = datetime.now(timezone.utc)

        # Store evidence (append to list or replace)
        if envelope.evidence_json is None:
            envelope.evidence_json = []
        if isinstance(envelope.evidence_json, list):
            envelope.evidence_json.append(payload)
        else:
            envelope.evidence_json = [payload]

        # Handle signed event
        if event_type == "signed":
            # Only transition if not already signed (idempotent)
            if contract.status != "signed":
                contract.status = "signed"
                contract.signed_at = datetime.now(timezone.utc)

                # Generate signed PDF
                counterparty = contract.counterparty
                offer = contract.offer

                if counterparty and offer:
                    counterparty_address = (
                        f"{counterparty.street}, {counterparty.postal_code} "
                        f"{counterparty.city}, {counterparty.country}"
                    )
                    signed_pdf_path = generate_signed_pdf(
                        contract_id=contract.id,
                        counterparty_name=counterparty.name,
                        counterparty_address=counterparty_address,
                        counterparty_email=counterparty.email,
                        offer_name=offer.name,
                        offer_price_cents=offer.price_cents,
                        offer_currency=offer.currency,
                        offer_billing_period=offer.billing_period,
                        signed_at=contract.signed_at,
                    )
                    contract.signed_pdf_path = signed_pdf_path

        session.commit()

        return {"ok": True}
