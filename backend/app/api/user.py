from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession
from ..db.database import get_db
from ..db import crud
from ..models.user import UserProfileCreate, UserProfileResponse
from ..core.security import verify_api_key

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/profile", response_model=UserProfileResponse)
async def get_profile(
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """Retrieve the user emergency profile (medical notes, blood group, emergency contacts)."""
    profile = await crud.get_user_profile(db, user_id="default")
    if not profile:
        return UserProfileResponse(
            id="default",
            name="",
            phone="",
            blood_group="",
            allergies="",
            medical_notes="",
            emergency_contacts=[],
        )
    return UserProfileResponse.model_validate(profile)


@router.post("/profile", response_model=UserProfileResponse, status_code=status.HTTP_200_OK)
async def save_profile(
    data: UserProfileCreate,
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """Create or update user emergency profile."""
    profile = await crud.upsert_user_profile(db, data, user_id="default")
    return UserProfileResponse.model_validate(profile)
