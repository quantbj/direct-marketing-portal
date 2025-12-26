import uuid
from datetime import datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.db.models.contract import Contract


class SignatureEnvelope(Base):
    """E-signature envelope model for tracking contract signing status."""

    __tablename__ = "signature_envelopes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    contract_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("contracts.id"), nullable=False, index=True
    )
    provider: Mapped[str] = mapped_column(String, nullable=False)
    provider_envelope_id: Mapped[str] = mapped_column(String, nullable=False, index=True)
    status: Mapped[str] = mapped_column(
        String, nullable=False
    )  # created, sent, signed, declined, voided, error
    signing_url: Mapped[Optional[str]] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()),
        onupdate=func.timezone("UTC", func.now()),
        nullable=False,
    )
    last_webhook_at: Mapped[Optional[datetime]] = mapped_column(nullable=True)
    evidence_json: Mapped[Optional[dict]] = mapped_column(JSONB, nullable=True)

    # Relationship
    contract: Mapped["Contract"] = relationship(back_populates="signature_envelopes")

    __table_args__ = (
        UniqueConstraint("provider", "provider_envelope_id", name="uq_provider_envelope"),
        Index("ix_signature_envelopes_contract_id", "contract_id"),
        Index("ix_signature_envelopes_provider_envelope_id", "provider_envelope_id"),
    )
