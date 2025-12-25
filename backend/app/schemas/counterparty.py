import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, field_validator


class CounterpartyCreate(BaseModel):
    """Schema for creating a counterparty."""

    type: Literal["person", "company"] = "person"
    name: str
    street: str
    postal_code: str
    city: str
    country: str = "DE"
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        """Validate email format."""
        # Simple email validation regex
        email_pattern = r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
        if not re.match(email_pattern, v):
            raise ValueError("Invalid email address format")
        return v

    @field_validator("country")
    @classmethod
    def validate_country(cls, v: str) -> str:
        """Validate country code matches ISO 3166-1 alpha-2 format."""
        if not re.match(r"^[A-Z]{2}$", v):
            raise ValueError("Country code must be exactly 2 uppercase letters (e.g., DE, US)")
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
