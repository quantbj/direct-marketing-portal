import enum
from datetime import datetime

from sqlalchemy import Enum, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ContractStatus(str, enum.Enum):
    """Contract status enum."""

    DRAFT = "draft"
    ACTIVE = "active"
    TERMINATED = "terminated"


class Contract(Base):
    """Contract domain model for direct marketing agreements."""

    __tablename__ = "contracts"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    customer_name: Mapped[str] = mapped_column(String, nullable=False)
    customer_email: Mapped[str] = mapped_column(String, nullable=False)
    status: Mapped[ContractStatus] = mapped_column(
        Enum(ContractStatus), nullable=False, default=ContractStatus.DRAFT
    )
    doc_version: Mapped[str] = mapped_column(String, nullable=False, default="1.0")
    created_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.timezone("UTC", func.now()),
        onupdate=func.timezone("UTC", func.now()),
        nullable=False,
    )
