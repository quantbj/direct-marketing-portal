import uuid

from fastapi import FastAPI, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.api.routes.counterparties import router as counterparties_router
from app.api.routes.offers import router as offers_router
from app.db.models.contract import Contract
from app.db.models.counterparty import Counterparty
from app.db.models.offer import Offer
from app.db.session import engine
from app.schemas.contract import ContractCreate, ContractResponse

app = FastAPI(title="Direct Marketing Contracts API")

# Include routers
app.include_router(counterparties_router)
app.include_router(offers_router)


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/health/db")
def health_db():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return {"ok": True}
    except Exception:
        raise HTTPException(status_code=503, detail="Database unavailable")


@app.post("/contracts", response_model=ContractResponse, status_code=201)
def create_contract(contract_data: ContractCreate):
    """Create a new contract."""
    with Session(engine) as session:
        # Verify counterparty exists
        counterparty = session.get(Counterparty, contract_data.counterparty_id)
        if not counterparty:
            raise HTTPException(status_code=404, detail="Counterparty not found")

        # Verify offer exists and is active
        offer = session.get(Offer, contract_data.offer_id)
        if not offer:
            raise HTTPException(status_code=422, detail="Offer not found")
        if not offer.is_active:
            raise HTTPException(status_code=422, detail="Offer is not active")

        contract = Contract(
            start_date=contract_data.start_date,
            end_date=contract_data.end_date,
            location_lat=contract_data.location_lat,
            location_lon=contract_data.location_lon,
            nab=contract_data.nab,
            technology=contract_data.technology.value,
            nominal_capacity=contract_data.nominal_capacity,
            indexation=contract_data.indexation.value,
            quantity_type=contract_data.quantity_type.value,
            counterparty_id=contract_data.counterparty_id,
            offer_id=contract_data.offer_id,
            solar_direction=contract_data.solar_direction,
            solar_inclination=contract_data.solar_inclination,
            wind_turbine_height=contract_data.wind_turbine_height,
        )
        session.add(contract)
        session.commit()
        session.refresh(contract)
        return contract


@app.get("/contracts/{contract_id}", response_model=ContractResponse)
def get_contract(contract_id: uuid.UUID):
    """Get a contract by ID."""
    with Session(engine) as session:
        contract = session.get(Contract, contract_id)
        if not contract:
            raise HTTPException(status_code=404, detail="Contract not found")
        return contract


@app.get("/contracts", response_model=list[ContractResponse])
def list_contracts(skip: int = 0, limit: int = 100):
    """List contracts with pagination."""
    with Session(engine) as session:
        contracts = session.query(Contract).offset(skip).limit(limit).all()
        return contracts
