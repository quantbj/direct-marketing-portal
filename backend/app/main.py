import uuid

from fastapi import FastAPI, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db.models.contract import Contract
from app.db.session import engine
from app.schemas.contract import ContractCreate, ContractResponse

app = FastAPI(title="Direct Marketing Contracts API")


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
