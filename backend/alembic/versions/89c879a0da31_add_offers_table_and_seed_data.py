"""add_offers_table_and_seed_data

Revision ID: 89c879a0da31
Revises: dd6dc3cf7ed5
Create Date: 2025-12-25 09:22:52.128482

"""

from typing import Sequence, Union

import sqlalchemy as sa

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "89c879a0da31"
down_revision: Union[str, Sequence[str], None] = "dd6dc3cf7ed5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Upgrade schema."""
    # Create offers table
    op.create_table(
        "offers",
        sa.Column("id", sa.Integer(), autoincrement=True, nullable=False),
        sa.Column("code", sa.String(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("description", sa.String(), nullable=True),
        sa.Column("currency", sa.String(), nullable=False, server_default="EUR"),
        sa.Column("price_cents", sa.Integer(), nullable=False),
        sa.Column("billing_period", sa.String(), nullable=False, server_default="monthly"),
        sa.Column("min_term_months", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("notice_period_days", sa.Integer(), nullable=False, server_default="14"),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column(
            "created_at",
            sa.DateTime(),
            server_default=sa.func.timezone("UTC", sa.func.now()),
            nullable=False,
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(),
            server_default=sa.func.timezone("UTC", sa.func.now()),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_offers_code"), "offers", ["code"], unique=True)
    op.create_index(op.f("ix_offers_is_active"), "offers", ["is_active"], unique=False)

    # Add offer_id to contracts table
    op.add_column("contracts", sa.Column("offer_id", sa.Integer(), nullable=True))
    op.create_foreign_key("fk_contracts_offer_id", "contracts", "offers", ["offer_id"], ["id"])

    # Seed 5 offers
    op.execute(
        """
        INSERT INTO offers (
            code, name, description, currency, price_cents,
            billing_period, min_term_months, notice_period_days, is_active
        )
        VALUES
            ('BASIC', 'Basic Plan', 'Perfect for small installations',
             'EUR', 9900, 'monthly', 1, 14, true),
            ('PRO', 'Professional Plan', 'Ideal for medium-sized operations',
             'EUR', 19900, 'monthly', 1, 14, true),
            ('ENTERPRISE', 'Enterprise Plan', 'For large-scale energy production',
             'EUR', 49900, 'monthly', 3, 14, true),
            ('PREMIUM', 'Premium Plan', 'Enhanced features and support',
             'EUR', 29900, 'monthly', 1, 14, true),
            ('STARTER', 'Starter Plan', 'Great for getting started',
             'EUR', 4900, 'monthly', 1, 14, true)
    """
    )


def downgrade() -> None:
    """Downgrade schema."""
    # Remove offer_id from contracts
    op.drop_constraint("fk_contracts_offer_id", "contracts", type_="foreignkey")
    op.drop_column("contracts", "offer_id")

    # Drop offers table
    op.drop_index(op.f("ix_offers_is_active"), table_name="offers")
    op.drop_index(op.f("ix_offers_code"), table_name="offers")
    op.drop_table("offers")
