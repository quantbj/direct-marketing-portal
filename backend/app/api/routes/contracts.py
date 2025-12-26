"""Contract API routes."""

import uuid

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.db.models.contract import Contract
from app.db.models.counterparty import Counterparty
from app.db.models.offer import Offer
from app.db.session import engine
from app.schemas.contract import ContractDraftCreate, ContractOut
from app.services.pdf_service import generate_draft_pdf, get_pdf_absolute_path

router = APIRouter(tags=["contracts"])


@router.post("/contracts/draft", response_model=ContractOut, status_code=201)
def create_contract_draft(draft_data: ContractDraftCreate):
    """
    Create a contract draft with PDF generation.

    Validates that counterparty and offer exist and are active,
    then creates a contract with status='draft' and generates a PDF placeholder.
    """
    with Session(engine) as session:
        # Validate counterparty exists
        counterparty = session.get(Counterparty, draft_data.counterparty_id)
        if not counterparty:
            raise HTTPException(status_code=404, detail="Counterparty not found")

        # Validate offer exists and is active
        offer = session.get(Offer, draft_data.offer_id)
        if not offer:
            raise HTTPException(status_code=404, detail="Offer not found")
        if not offer.is_active:
            raise HTTPException(status_code=422, detail="Offer is not active")

        # Create contract with draft status
        contract = Contract(
            counterparty_id=draft_data.counterparty_id,
            offer_id=draft_data.offer_id,
            status="draft",
        )
        session.add(contract)
        session.flush()  # Get the contract ID before generating PDF

        # Generate PDF
        counterparty_address = (
            f"{counterparty.street}, {counterparty.postal_code} "
            f"{counterparty.city}, {counterparty.country}"
        )
        pdf_path = generate_draft_pdf(
            contract_id=contract.id,
            counterparty_name=counterparty.name,
            counterparty_address=counterparty_address,
            counterparty_email=counterparty.email,
            offer_name=offer.name,
            offer_price_cents=offer.price_cents,
            offer_currency=offer.currency,
            offer_billing_period=offer.billing_period,
        )

        # Update contract with PDF path
        contract.draft_pdf_path = pdf_path
        session.commit()
        session.refresh(contract)

        # Prepare response
        return ContractOut(
            id=contract.id,
            status=contract.status,
            counterparty_id=contract.counterparty_id,
            offer_id=contract.offer_id,
            draft_pdf_available=contract.draft_pdf_path is not None,
            created_at=contract.created_at,
            updated_at=contract.updated_at,
        )


@router.get("/contracts/{contract_id}/draft-pdf")
def download_draft_pdf(contract_id: uuid.UUID):
    """
    Download the draft PDF for a contract.

    Returns the PDF file if it exists, otherwise returns 404.
    """
    with Session(engine) as session:
        contract = session.get(Contract, contract_id)

        if not contract:
            raise HTTPException(status_code=404, detail="Contract not found")

        if not contract.draft_pdf_path:
            raise HTTPException(status_code=404, detail="Draft PDF not found")

        # Get absolute path and verify file exists
        pdf_path = get_pdf_absolute_path(contract.draft_pdf_path)
        if not pdf_path.exists():
            raise HTTPException(status_code=404, detail="Draft PDF file not found on disk")

        return FileResponse(
            path=str(pdf_path),
            media_type="application/pdf",
            filename=f"contract_{contract_id}_draft.pdf",
        )
