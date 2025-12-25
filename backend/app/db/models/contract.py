import uuid
from datetime import date, datetime
from typing import TYPE_CHECKING, Optional

from sqlalchemy import CheckConstraint, Date, Float, ForeignKey, Numeric, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base

if TYPE_CHECKING:
    from app.db.models.counterparty import Counterparty
    from app.db.models.offer import Offer


class Contract(Base):
    """Contract domain model for energy direct marketing agreements."""

    __tablename__ = "contracts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    location_lat: Mapped[float] = mapped_column(Float, nullable=False)
    location_lon: Mapped[float] = mapped_column(Float, nullable=False)
    nab: Mapped[int] = mapped_column(nullable=False)
    technology: Mapped[str] = mapped_column(String, nullable=False)
    nominal_capacity: Mapped[float] = mapped_column(
        Numeric(precision=10, scale=2), nullable=False
    )  # unit = kW
    indexation: Mapped[str] = mapped_column(String, nullable=False)
    quantity_type: Mapped[str] = mapped_column(String, nullable=False)

    # Technology-specific fields (nullable)
    solar_direction: Mapped[Optional[int]] = mapped_column(nullable=True)
    solar_inclination: Mapped[Optional[int]] = mapped_column(nullable=True)
    wind_turbine_height: Mapped[Optional[float]] = mapped_column(
        Numeric(precision=10, scale=2), nullable=True
    )

    # Counterparty relationship
    counterparty_id: Mapped[Optional[int]] = mapped_column(
        ForeignKey("counterparties.id"), nullable=True
    )

    # Offer relationship
    offer_id: Mapped[Optional[int]] = mapped_column(ForeignKey("offers.id"), nullable=True)

    created_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()),
        onupdate=func.timezone("UTC", func.now()),
        nullable=False,
    )

    # Relationships
    counterparty: Mapped[Optional["Counterparty"]] = relationship(back_populates="contracts")
    offer: Mapped[Optional["Offer"]] = relationship()

    __table_args__ = (
        CheckConstraint("location_lat >= -90 AND location_lat <= 90", name="valid_latitude"),
        CheckConstraint("location_lon >= -180 AND location_lon <= 180", name="valid_longitude"),
        CheckConstraint("nominal_capacity > 0", name="positive_capacity"),
    )
