"""make_contract_fields_nullable_for_drafts

Revision ID: f7e0834b86f6
Revises: a5405f601134
Create Date: 2025-12-26 10:22:29.220070

"""

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "f7e0834b86f6"
down_revision: Union[str, Sequence[str], None] = "a5405f601134"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Make contract fields nullable to support draft contracts
    op.alter_column("contracts", "start_date", nullable=True)
    op.alter_column("contracts", "end_date", nullable=True)
    op.alter_column("contracts", "location_lat", nullable=True)
    op.alter_column("contracts", "location_lon", nullable=True)
    op.alter_column("contracts", "nab", nullable=True)
    op.alter_column("contracts", "technology", nullable=True)
    op.alter_column("contracts", "nominal_capacity", nullable=True)
    op.alter_column("contracts", "indexation", nullable=True)
    op.alter_column("contracts", "quantity_type", nullable=True)


def downgrade() -> None:
    """Downgrade schema."""
    # Revert fields to NOT NULL
    op.alter_column("contracts", "quantity_type", nullable=False)
    op.alter_column("contracts", "indexation", nullable=False)
    op.alter_column("contracts", "nominal_capacity", nullable=False)
    op.alter_column("contracts", "technology", nullable=False)
    op.alter_column("contracts", "nab", nullable=False)
    op.alter_column("contracts", "location_lon", nullable=False)
    op.alter_column("contracts", "location_lat", nullable=False)
    op.alter_column("contracts", "end_date", nullable=False)
    op.alter_column("contracts", "start_date", nullable=False)
