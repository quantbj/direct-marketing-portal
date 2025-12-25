from fastapi import FastAPI, HTTPException
from sqlalchemy import text

from app.api.routes import contracts, counterparties
from app.db.session import engine

app = FastAPI(title="Direct Marketing Contracts API")

# Include routers
app.include_router(counterparties.router)
app.include_router(contracts.router)


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
