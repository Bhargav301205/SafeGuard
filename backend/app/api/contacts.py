from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from ..db.database import get_db
from ..db import crud
from ..models.contact import ContactCreate, ContactResponse
from ..core.security import verify_api_key

router = APIRouter(prefix="/contacts", tags=["contacts"])


@router.post("", response_model=ContactResponse, status_code=status.HTTP_201_CREATED)
async def add_contact(
    data: ContactCreate,
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """Add or upsert an emergency contact."""
    obj = await crud.create_contact(db, data)
    return ContactResponse.model_validate(obj)


@router.get("", response_model=list[ContactResponse])
async def list_contacts(
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """List all saved emergency contacts."""
    contacts = await crud.list_contacts(db)
    return [ContactResponse.model_validate(c) for c in contacts]


@router.delete("/{contact_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_contact(
    contact_id: str,
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """Remove an emergency contact by ID."""
    deleted = await crud.delete_contact(db, contact_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Contact not found")
