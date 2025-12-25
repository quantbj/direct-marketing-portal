"""Contract API routes."""

import uuid

from fastapi import APIRouter, HTTPException
from sqlalchemy.orm import Session

from app.api.schemas.contract import ContractCreate, ContractResponse
from app.db.models.contract import Contract
from app.db.models.counterparty import Counterparty
from app.db.session import engine

router = APIRouter(prefix="/contracts", tags=["contracts"])


@router.post("", response_model=ContractResponse, status_code=201)
def create_contract(contract_data: ContractCreate):
    """Create a new contract."""
    with Session(engine) as session:
        # Verify counterparty exists
        counterparty = session.get(Counterparty, contract_data.counterparty_id)
        if not counterparty:
            raise HTTPException(
                status_code=404,
                detail=f"Counterparty with id {contract_data.counterparty_id} not found",
            )

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
            counterparty_id=contract_data.counterparty_id,
        )
        session.add(contract)
        session.commit()
        session.refresh(contract)
        return contract


@router.get("/{contract_id}", response_model=ContractResponse)
def get_contract(contract_id: uuid.UUID):
    """Get a contract by ID."""
    with Session(engine) as session:
        contract = session.get(Contract, contract_id)
        if not contract:
            raise HTTPException(status_code=404, detail="Contract not found")
        return contract


@router.get("", response_model=list[ContractResponse])
def list_contracts(skip: int = 0, limit: int = 100):
    """List contracts with pagination."""
    with Session(engine) as session:
        contracts = session.query(Contract).offset(skip).limit(limit).all()
        return contracts
