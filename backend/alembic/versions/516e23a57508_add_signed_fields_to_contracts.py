"""add_signed_fields_to_contracts

Revision ID: 516e23a57508
Revises: f7e0834b86f6
Create Date: 2025-12-26 10:59:00.310204

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "516e23a57508"
down_revision: Union[str, Sequence[str], None] = "f7e0834b86f6"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add signed_at column (nullable)
    op.add_column("contracts", sa.Column("signed_at", sa.DateTime(timezone=True), nullable=True))
    # Add signed_pdf_path column (nullable)
    op.add_column("contracts", sa.Column("signed_pdf_path", sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("contracts", "signed_pdf_path")
    op.drop_column("contracts", "signed_at")
