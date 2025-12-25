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

    @field_validator("country")
    @classmethod
    def validate_country(cls, v: str) -> str:
        """Validate country code is 2 uppercase letters."""
        import re

        if not re.match(r"^[A-Z]{2}$", v):
            raise ValueError("Country must be a 2-letter uppercase code (e.g., DE, US, FR)")
        return v

    @field_validator("type")
    @classmethod
    def validate_type(cls, v: str) -> str:
        """Validate type is either 'person' or 'company'."""
        if v not in ["person", "company"]:
            raise ValueError("Type must be either 'person' or 'company'")
        return v


class CounterpartyRead(BaseModel):
    """Schema for counterparty response."""

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
