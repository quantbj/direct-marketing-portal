from fastapi import APIRouter, HTTPException
from sqlalchemy.orm import Session

from app.db.models.counterparty import Counterparty
from app.db.session import engine
from app.schemas.counterparty import CounterpartyCreate, CounterpartyResponse

router = APIRouter(prefix="/counterparties", tags=["counterparties"])


@router.post("", response_model=CounterpartyResponse, status_code=201)
def create_counterparty(counterparty_data: CounterpartyCreate):
    """Create a new counterparty."""
    with Session(engine) as session:
        counterparty = Counterparty(
            type=counterparty_data.type,
            name=counterparty_data.name,
            street=counterparty_data.street,
            postal_code=counterparty_data.postal_code,
            city=counterparty_data.city,
            country=counterparty_data.country,
            email=counterparty_data.email,
        )
        session.add(counterparty)
        session.commit()
        session.refresh(counterparty)
        return counterparty


@router.get("/{counterparty_id}", response_model=CounterpartyResponse)
def get_counterparty(counterparty_id: int):
    """Get a counterparty by ID."""
    with Session(engine) as session:
        counterparty = session.get(Counterparty, counterparty_id)
        if not counterparty:
            raise HTTPException(status_code=404, detail="Counterparty not found")
        return counterparty
