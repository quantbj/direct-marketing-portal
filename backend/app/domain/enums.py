"""Domain enums for contracts."""

import enum


class Technology(str, enum.Enum):
    """Energy technology types."""

    SOLAR = "solar"
    WIND = "wind"


class Indexation(str, enum.Enum):
    """Price indexation methods."""

    DAY_AHEAD = "day_ahead"
    MONTH_AHEAD = "month_ahead"


class QuantityType(str, enum.Enum):
    """Quantity calculation types."""

    PAY_AS_PRODUCED = "pay_as_produced"
    PAY_AS_FORECASTED = "pay_as_forecasted"
