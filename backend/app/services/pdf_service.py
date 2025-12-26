"""PDF generation service for contract drafts."""

import html
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path

from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.units import cm
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer

from app.core.config import settings


def generate_draft_pdf(
    contract_id: uuid.UUID,
    counterparty_name: str,
    counterparty_address: str,
    counterparty_email: str,
    offer_name: str,
    offer_price_cents: int,
    offer_currency: str,
    offer_billing_period: str,
) -> str:
    """
    Generate a placeholder PDF for a contract draft.

    Args:
        contract_id: UUID of the contract
        counterparty_name: Name of the counterparty
        counterparty_address: Full address of the counterparty
        counterparty_email: Email of the counterparty
        offer_name: Name of the offer/plan
        offer_price_cents: Price in cents
        offer_currency: Currency code (e.g., EUR)
        offer_billing_period: Billing period (e.g., monthly)

    Returns:
        str: Relative path to the generated PDF
    """
    # Create storage directory for this contract
    contract_storage_dir = Path(settings.STORAGE_ROOT) / "contracts" / str(contract_id)
    contract_storage_dir.mkdir(parents=True, exist_ok=True)

    # Define PDF file path
    pdf_filename = "draft.pdf"
    pdf_path = contract_storage_dir / pdf_filename

    # Create PDF document
    doc = SimpleDocTemplate(str(pdf_path), pagesize=A4)
    styles = getSampleStyleSheet()
    story = []

    # Title
    title = Paragraph("<b>CONTRACT DRAFT</b>", styles["Title"])
    story.append(title)
    story.append(Spacer(1, 1 * cm))

    # Contract information
    contract_info = f"""
    <b>Contract ID:</b> {contract_id}<br/>
    <b>Draft Generated:</b> {datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")}<br/>
    """
    story.append(Paragraph(contract_info, styles["Normal"]))
    story.append(Spacer(1, 0.5 * cm))

    # Counterparty information (escape user input to prevent XSS)
    counterparty_section = f"""
    <b>Counterparty Information</b><br/>
    Name: {html.escape(counterparty_name)}<br/>
    Address: {html.escape(counterparty_address)}<br/>
    Email: {html.escape(counterparty_email)}<br/>
    """
    story.append(Paragraph(counterparty_section, styles["Normal"]))
    story.append(Spacer(1, 0.5 * cm))

    # Offer information (escape user input)
    price_display = f"{offer_price_cents / 100:.2f} {html.escape(offer_currency)}"
    offer_section = f"""
    <b>Offer Details</b><br/>
    Plan: {html.escape(offer_name)}<br/>
    Price: {price_display}<br/>
    Billing Period: {html.escape(offer_billing_period)}<br/>
    """
    story.append(Paragraph(offer_section, styles["Normal"]))
    story.append(Spacer(1, 1 * cm))

    # Placeholder notice
    notice = Paragraph(
        "<i>This is a placeholder contract draft. "
        "Final contract templates will be implemented in a future release.</i>",
        styles["Italic"],
    )
    story.append(notice)

    # Build PDF
    doc.build(story)

    # Return relative path from storage root
    relative_path = os.path.relpath(pdf_path, settings.STORAGE_ROOT)
    return relative_path


def get_pdf_absolute_path(relative_path: str) -> Path:
    """
    Get the absolute path to a PDF file from its relative storage path.

    Args:
        relative_path: Relative path from storage root

    Returns:
        Path: Absolute path to the PDF file
    """
    return Path(settings.STORAGE_ROOT) / relative_path
