"""add_contract_status_and_pdf_path

Revision ID: a5405f601134
Revises: 89c879a0da31
Create Date: 2025-12-26 10:18:28.376185

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a5405f601134"
down_revision: Union[str, Sequence[str], None] = "89c879a0da31"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Add status column (default 'draft')
    op.add_column(
        "contracts",
        sa.Column("status", sa.String(), nullable=False, server_default="draft"),
    )
    # Add draft_pdf_path column (nullable)
    op.add_column("contracts", sa.Column("draft_pdf_path", sa.String(), nullable=True))


def downgrade() -> None:
    """Downgrade schema."""
    op.drop_column("contracts", "draft_pdf_path")
    op.drop_column("contracts", "status")
