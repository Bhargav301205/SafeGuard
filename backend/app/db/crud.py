from datetime import datetime
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession
from ..models.incident import IncidentORM, IncidentCreate
from ..models.contact import ContactORM, ContactCreate
from ..models.user import UserORM, UserProfileCreate


# ── Incidents ────────────────────────────────────────────────────────────────

async def create_incident(db: AsyncSession, data: IncidentCreate) -> IncidentORM:
    obj = IncidentORM(
        id=data.id,
        timestamp=datetime.fromisoformat(data.timestamp) if data.timestamp else datetime.utcnow(),
        lat=data.lat,
        lng=data.lng,
        address=data.address,
        status=data.status,
        sensor_snapshot=data.sensorSnapshot.model_dump(),
        contacts_notified=data.contactsNotified,
        emergency_call_placed=data.emergencyCallPlaced,
    )
    db.add(obj)
    await db.commit()
    await db.refresh(obj)
    return obj


async def get_incident(db: AsyncSession, incident_id: str) -> IncidentORM | None:
    result = await db.execute(select(IncidentORM).where(IncidentORM.id == incident_id))
    return result.scalar_one_or_none()


async def list_incidents(db: AsyncSession, skip: int = 0, limit: int = 50) -> list[IncidentORM]:
    result = await db.execute(
        select(IncidentORM).order_by(IncidentORM.timestamp.desc()).offset(skip).limit(limit)
    )
    return list(result.scalars().all())


# ── Contacts ─────────────────────────────────────────────────────────────────

async def create_contact(db: AsyncSession, data: ContactCreate) -> ContactORM:
    # Upsert by ID
    existing = await db.execute(select(ContactORM).where(ContactORM.id == data.id))
    obj = existing.scalar_one_or_none()
    if obj:
        obj.name = data.name
        obj.email = data.email
        obj.phone = data.phone
        obj.relation = data.relation
    else:
        obj = ContactORM(
            id=data.id,
            name=data.name,
            email=data.email,
            phone=data.phone,
            relation=data.relation,
        )
        db.add(obj)
    await db.commit()
    await db.refresh(obj)
    return obj


async def list_contacts(db: AsyncSession) -> list[ContactORM]:
    result = await db.execute(select(ContactORM))
    return list(result.scalars().all())


async def delete_contact(db: AsyncSession, contact_id: str) -> bool:
    result = await db.execute(delete(ContactORM).where(ContactORM.id == contact_id))
    await db.commit()
    return result.rowcount > 0


# ── User Profile ─────────────────────────────────────────────────────────────

async def get_user_profile(db: AsyncSession, user_id: str = "default") -> UserORM | None:
    result = await db.execute(select(UserORM).where(UserORM.id == user_id))
    return result.scalar_one_or_none()


async def upsert_user_profile(db: AsyncSession, data: UserProfileCreate, user_id: str = "default") -> UserORM:
    existing = await get_user_profile(db, user_id)
    if existing:
        existing.name = data.name
        existing.phone = data.phone
        existing.blood_group = data.blood_group
        existing.allergies = data.allergies
        existing.medical_notes = data.medical_notes
        existing.emergency_contacts = data.emergency_contacts
        obj = existing
    else:
        obj = UserORM(
            id=user_id,
            name=data.name,
            phone=data.phone,
            blood_group=data.blood_group,
            allergies=data.allergies,
            medical_notes=data.medical_notes,
            emergency_contacts=data.emergency_contacts,
        )
        db.add(obj)
    await db.commit()
    await db.refresh(obj)
    return obj
