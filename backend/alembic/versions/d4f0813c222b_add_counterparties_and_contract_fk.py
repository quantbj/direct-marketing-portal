"""add_counterparties_and_contract_fk

Revision ID: d4f0813c222b
Revises: 0b221ccc449c
Create Date: 2025-12-25 08:44:58.814588

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4f0813c222b'
down_revision: Union[str, Sequence[str], None] = '0b221ccc449c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create counterparties table
    op.create_table(
        "counterparties",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("type", sa.String(), nullable=False, server_default="person"),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("street", sa.String(), nullable=False),
        sa.Column("postal_code", sa.String(), nullable=False),
        sa.Column("city", sa.String(), nullable=False),
        sa.Column("country", sa.String(), nullable=False, server_default="DE"),
        sa.Column("email", sa.String(), nullable=False),
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
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_counterparties_email", "counterparties", ["email"])

    # Add counterparty_id foreign key to contracts table
    op.add_column(
        "contracts",
        sa.Column("counterparty_id", sa.Integer(), nullable=True),
    )
    op.create_foreign_key(
        "fk_contracts_counterparty_id",
        "contracts",
        "counterparties",
        ["counterparty_id"],
        ["id"],
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Drop foreign key and column from contracts
    op.drop_constraint("fk_contracts_counterparty_id", "contracts", type_="foreignkey")
    op.drop_column("contracts", "counterparty_id")

    # Drop counterparties table
    op.drop_index("ix_counterparties_email", table_name="counterparties")
    op.drop_table("counterparties")
