"""add_signature_envelopes_table

Revision ID: e021595b9ec2
Revises: 516e23a57508
Create Date: 2025-12-26 10:59:26.938038

"""

from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import JSONB, UUID

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "e021595b9ec2"
down_revision: Union[str, Sequence[str], None] = "516e23a57508"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create signature_envelopes table
    op.create_table(
        "signature_envelopes",
        sa.Column("id", UUID(as_uuid=True), primary_key=True, nullable=False),
        sa.Column("contract_id", UUID(as_uuid=True), nullable=False),
        sa.Column("provider", sa.String(), nullable=False),
        sa.Column("provider_envelope_id", sa.String(), nullable=False),
        sa.Column("status", sa.String(), nullable=False),
        sa.Column("signing_url", sa.String(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("timezone('UTC', now())"),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            nullable=False,
            server_default=sa.text("timezone('UTC', now())"),
        ),
        sa.Column("last_webhook_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("evidence_json", JSONB, nullable=True),
        sa.ForeignKeyConstraint(["contract_id"], ["contracts.id"]),
    )
    # Create indexes
    op.create_index("ix_signature_envelopes_contract_id", "signature_envelopes", ["contract_id"])
    op.create_index(
        "ix_signature_envelopes_provider_envelope_id",
        "signature_envelopes",
        ["provider_envelope_id"],
    )
    # Create unique constraint
    op.create_unique_constraint(
        "uq_provider_envelope", "signature_envelopes", ["provider", "provider_envelope_id"]
    )


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_constraint("uq_provider_envelope", "signature_envelopes")
    op.drop_index("ix_signature_envelopes_provider_envelope_id", "signature_envelopes")
    op.drop_index("ix_signature_envelopes_contract_id", "signature_envelopes")
    op.drop_table("signature_envelopes")
