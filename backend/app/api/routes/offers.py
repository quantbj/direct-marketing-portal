"""API routes for offers."""

from fastapi import APIRouter, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models.offer import Offer
from app.db.session import engine
from app.schemas.offer import OfferResponse

router = APIRouter(prefix="/offers", tags=["offers"])


@router.get("", response_model=list[OfferResponse])
def list_offers():
    """List all active offers ordered by price."""
    with Session(engine) as session:
        stmt = select(Offer).where(Offer.is_active.is_(True)).order_by(Offer.price_cents)
        offers = session.execute(stmt).scalars().all()
        return offers


@router.get("/{offer_id}", response_model=OfferResponse)
def get_offer(offer_id: int):
    """Get a specific offer by ID."""
    with Session(engine) as session:
        offer = session.get(Offer, offer_id)
        if not offer:
            raise HTTPException(status_code=404, detail="Offer not found")
        return offer
