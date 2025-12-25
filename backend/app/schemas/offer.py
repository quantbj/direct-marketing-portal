"""Pydantic schemas for Offer API."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class OfferResponse(BaseModel):
    """Schema for offer response."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    description: str | None
    currency: str
    price_cents: int
    billing_period: str
    min_term_months: int
    notice_period_days: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
