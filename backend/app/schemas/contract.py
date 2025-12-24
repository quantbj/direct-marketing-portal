from datetime import datetime

from pydantic import BaseModel, ConfigDict, field_validator

from app.db.models.contract import ContractStatus


class ContractCreate(BaseModel):
    """Schema for creating a contract."""

    customer_name: str
    customer_email: str
    doc_version: str = "1.0"

    @field_validator("customer_email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Basic email validation."""
        if "@" not in v or "." not in v.split("@")[-1]:
            raise ValueError("Invalid email format")
        return v


class ContractResponse(BaseModel):
    """Schema for contract response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    customer_name: str
    customer_email: str
    status: ContractStatus
    doc_version: str
    created_at: datetime
    updated_at: datetime
