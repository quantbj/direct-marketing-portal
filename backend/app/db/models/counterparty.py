from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import Index, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.db.models.contract import Contract


class Counterparty(Base):
    """Counterparty model for contract parties (person or company)."""

    __tablename__ = "counterparties"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    type: Mapped[str] = mapped_column(String, nullable=False, default="person")
    name: Mapped[str] = mapped_column(String, nullable=False)
    street: Mapped[str] = mapped_column(String, nullable=False)
    postal_code: Mapped[str] = mapped_column(String, nullable=False)
    city: Mapped[str] = mapped_column(String, nullable=False)
    country: Mapped[str] = mapped_column(String, nullable=False, default="DE")
    email: Mapped[str] = mapped_column(String, nullable=False, unique=True)

    created_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()),
        onupdate=func.timezone("UTC", func.now()),
        nullable=False,
    )

    # Relationship to contracts
    contracts: Mapped[list["Contract"]] = relationship("Contract", back_populates="counterparty")

    __table_args__ = (Index("ix_counterparties_email", "email"),)
