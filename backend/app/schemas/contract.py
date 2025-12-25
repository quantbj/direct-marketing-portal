import uuid
from datetime import date, datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator

from app.domain.enums import Indexation, QuantityType, Technology


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
                raise ValueError("wind_turbine_height should only be provided for wind technology")
        return v


class ContractResponse(BaseModel):
    """Schema for contract response."""

    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    start_date: date
    end_date: date
    location_lat: float
    location_lon: float
    nab: int
    technology: str
    nominal_capacity: float
    indexation: str
    quantity_type: str
    solar_direction: Optional[int]
    solar_inclination: Optional[int]
    wind_turbine_height: Optional[float]
    created_at: datetime
    updated_at: datetime
