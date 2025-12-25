"""replace_contracts_with_energy_model

Revision ID: 0b221ccc449c
Revises: b472eeaeb2fe
Create Date: 2025-12-25 07:34:51.832280

"""

from typing import Sequence, Union

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "0b221ccc449c"
down_revision: Union[str, Sequence[str], None] = "b472eeaeb2fe"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Drop the old contracts table
    op.drop_table("contracts")
    op.execute("DROP TYPE IF EXISTS contractstatus")

    # Create the new contracts table for energy contracts
    op.create_table(
        "contracts",
        sa.Column("id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("start_date", sa.Date(), nullable=False),
        sa.Column("end_date", sa.Date(), nullable=False),
        sa.Column("location_lat", sa.Float(), nullable=False),
        sa.Column("location_lon", sa.Float(), nullable=False),
        sa.Column("nab", sa.Integer(), nullable=False),
        sa.Column("technology", sa.String(), nullable=False),
        sa.Column("nominal_capacity", sa.Numeric(precision=10, scale=2), nullable=False),
        sa.Column("indexation", sa.String(), nullable=False),
        sa.Column("quantity_type", sa.String(), nullable=False),
        sa.Column("solar_direction", sa.Integer(), nullable=True),
        sa.Column("solar_inclination", sa.Integer(), nullable=True),
        sa.Column("wind_turbine_height", sa.Numeric(precision=10, scale=2), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("timezone('UTC', now())"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.text("timezone('UTC', now())"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.CheckConstraint("location_lat >= -90 AND location_lat <= 90", name="valid_latitude"),
        sa.CheckConstraint("location_lon >= -180 AND location_lon <= 180", name="valid_longitude"),
        sa.CheckConstraint("nominal_capacity > 0", name="positive_capacity"),
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Drop the new contracts table
    op.drop_table("contracts")

    # Recreate the old contracts table
    op.create_table(
        "contracts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("customer_name", sa.String(), nullable=False),
        sa.Column("customer_email", sa.String(), nullable=False),
        sa.Column(
            "status",
            sa.Enum("DRAFT", "ACTIVE", "TERMINATED", name="contractstatus"),
            nullable=False,
        ),
        sa.Column("doc_version", sa.String(), nullable=False),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.text("timezone('UTC', now())"),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.text("timezone('UTC', now())"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
