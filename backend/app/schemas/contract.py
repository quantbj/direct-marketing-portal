from datetime import datetime

from pydantic import BaseModel, ConfigDict

from app.db.models.contract import ContractStatus


class ContractCreate(BaseModel):
    """Schema for creating a contract."""

    customer_name: str
    customer_email: str
    doc_version: str = "1.0"


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
