"""Counterparty API schemas."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, field_validator


class CounterpartyCreate(BaseModel):
    """Schema for creating a counterparty."""

    type: str = "person"
    name: str
    street: str
    postal_code: str
    city: str
    country: str = "DE"
    email: EmailStr

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        """Validate counterparty type."""
        if v not in ["person", "company"]:
            raise ValueError("Type must be 'person' or 'company'")
        return v

    @field_validator("country")
    @classmethod
    def validate_country(cls, v: str) -> str:
        """Validate country code is 2 uppercase letters."""
        if not v or len(v) != 2 or not v.isupper() or not v.isalpha():
            raise ValueError("Country must be a 2-letter uppercase code (e.g., 'DE', 'US')")
        return v


class CounterpartyRead(BaseModel):
    """Schema for reading a counterparty."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    type: str
    name: str
    street: str
    postal_code: str
    city: str
    country: str
    email: str
    created_at: datetime
    updated_at: datetime
