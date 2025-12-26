import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator

from app.domain.enums import Indexation, QuantityType, Technology


class ContractDraftCreate(BaseModel):
    """Schema for creating a contract draft."""

    counterparty_id: int
    offer_id: int


class ContractCreate(BaseModel):
    """Schema for creating a contract."""

    start_date: date
    end_date: date
    location_lat: float
    location_lon: float
    nab: int
    technology: Technology
    nominal_capacity: float  # unit = kW
    indexation: Indexation
    quantity_type: QuantityType
    counterparty_id: int
    offer_id: int

    # Technology-specific fields (nullable)
    solar_direction: Optional[int] = None
    solar_inclination: Optional[int] = None
    wind_turbine_height: Optional[float] = None

    @field_validator("location_lat")
    @classmethod
    def validate_latitude(cls, v: float) -> float:
        """Validate latitude range."""
        if not -90 <= v <= 90:
            raise ValueError("Latitude must be between -90 and 90")
        return v

    @field_validator("location_lon")
    @classmethod
    def validate_longitude(cls, v: float) -> float:
        """Validate longitude range."""
        if not -180 <= v <= 180:
            raise ValueError("Longitude must be between -180 and 180")
        return v

    @field_validator("nominal_capacity")
    @classmethod
    def validate_capacity(cls, v: float) -> float:
        """Validate nominal capacity is positive."""
        if v <= 0:
            raise ValueError("Nominal capacity must be positive")
        return v

    @field_validator("end_date")
    @classmethod
    def validate_dates(cls, v: date, info) -> date:
        """Validate end_date is after start_date."""
        if "start_date" in info.data and v <= info.data["start_date"]:
            raise ValueError("end_date must be after start_date")
        return v

    @field_validator("solar_direction")
    @classmethod
    def validate_solar_direction(cls, v: Optional[int], info) -> Optional[int]:
        """Validate solar direction field."""
        if v is not None:
            technology = info.data.get("technology")
            if technology != Technology.SOLAR:
                raise ValueError("Solar fields should only be provided for solar technology")
            if not 0 <= v < 360:
                raise ValueError("Solar direction must be between 0 and 359 degrees")
        return v

    @field_validator("solar_inclination")
    @classmethod
    def validate_solar_inclination(cls, v: Optional[int], info) -> Optional[int]:
        """Validate solar inclination field."""
        if v is not None:
            technology = info.data.get("technology")
            if technology != Technology.SOLAR:
                raise ValueError("Solar fields should only be provided for solar technology")
            if not 0 <= v <= 90:
                raise ValueError("Solar inclination must be between 0 and 90 degrees")
        return v

    @field_validator("wind_turbine_height")
    @classmethod
    def validate_wind_turbine_height(cls, v: Optional[float], info) -> Optional[float]:
        """Validate wind turbine height field."""
        if v is not None:
            technology = info.data.get("technology")
            if technology != Technology.WIND:
                raise ValueError("Wind turbine height should only be provided for wind technology")
        return v


class CounterpartySummary(BaseModel):
    """Summary of counterparty information."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    email: str
    street: str
    postal_code: str
    city: str
    country: str


class OfferSummary(BaseModel):
    """Summary of offer information."""

    model_config = ConfigDict(from_attributes=True)

    id: int
    code: str
    name: str
    price_cents: int
    currency: str
    billing_period: str


class ContractOut(BaseModel):
    """Schema for contract output with embedded counterparty and offer."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    status: str
    counterparty_id: Optional[int]
    offer_id: Optional[int]
    draft_pdf_available: bool
    counterparty: Optional[CounterpartySummary] = None
    offer: Optional[OfferSummary] = None
    created_at: datetime
    updated_at: datetime


class ContractResponse(BaseModel):
    """Schema for contract response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    start_date: Optional[date]
    end_date: Optional[date]
    location_lat: Optional[float]
    location_lon: Optional[float]
    nab: Optional[int]
    technology: Optional[str]
    nominal_capacity: Optional[float]
    indexation: Optional[str]
    quantity_type: Optional[str]
    counterparty_id: Optional[int]
    offer_id: Optional[int]
    solar_direction: Optional[int]
    solar_inclination: Optional[int]
    wind_turbine_height: Optional[float]
    status: str
    draft_pdf_path: Optional[str]
    created_at: datetime
    updated_at: datetime
    counterparty: Optional[CounterpartySummary] = None
    offer: Optional[OfferSummary] = None
