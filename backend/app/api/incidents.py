from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from ..db.database import get_db
from ..db import crud
from ..models.incident import IncidentCreate, IncidentResponse
from ..core.security import verify_api_key
from ..services.email_service import email_service
from ..services.notification_service import notification_service
import logging

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/incidents", tags=["incidents"])


@router.post("", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
async def create_incident(
    data: IncidentCreate,
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """Log a new crash incident, send email alerts, and place automated AI voice calls to contacts."""

    if data.status == "confirmed":
        # Get all saved contacts from DB
        db_contacts = await crud.list_contacts(db)

        # Build contact list with name + email
        contact_list = []
        for c in db_contacts:
            email_addr = getattr(c, "email", None) or getattr(c, "phone", None) or ""
            if email_addr and "@" in email_addr:
                contact_list.append({"name": c.name, "email": email_addr})

        # Also include any emails sent from the app directly (contactsNotified)
        existing_emails = {c["email"].lower() for c in contact_list}
        if data.contactsNotified:
            for item in data.contactsNotified:
                if isinstance(item, str) and "@" in item:
                    clean_email = item.strip()
                    if clean_email.lower() not in existing_emails:
                        contact_list.append({"name": "Emergency Contact", "email": clean_email})
                        existing_emails.add(clean_email.lower())

        if contact_list:
            g_force = 0.0
            try:
                sensor = data.sensorSnapshot
                if sensor and hasattr(sensor, "gForce"):
                    g_force = float(sensor.gForce)
                elif isinstance(sensor, dict):
                    g_force = float(sensor.get("gForce", 0))
            except Exception:
                pass

            logger.info(f"[Incidents] Sending email alerts to {len(contact_list)} contacts")
            notified_emails = await email_service.send_alert(
                contacts=contact_list,
                address=data.address or "Location unavailable",
                lat=data.lat or 0.0,
                lng=data.lng or 0.0,
                g_force=g_force,
                timestamp=data.timestamp,
            )
            logger.info(f"[Incidents] Emails sent to: {notified_emails}")

            # Update contactsNotified with actual sent emails
            if notified_emails:
                data.contactsNotified = notified_emails
        else:
            logger.info("[Incidents] No email contacts configured — skipping email alerts.")

        # Place automated AI voice calls to all contacts with phone numbers
        phone_contacts = []
        for c in db_contacts:
            phone_num = getattr(c, "phone", None) or ""
            if phone_num and len(phone_num.strip()) >= 7 and "@" not in phone_num:
                phone_contacts.append({"name": c.name, "phone": phone_num.strip()})

        if phone_contacts:
            logger.info(f"[Incidents] Initiating automated AI voice calls to {len(phone_contacts)} contacts")
            await notification_service.call_contacts(
                contacts=phone_contacts,
                address=data.address or "Location unavailable",
                lat=data.lat or 0.0,
                lng=data.lng or 0.0,
            )

    obj = await crud.create_incident(db, data)
    return IncidentResponse.from_orm_model(obj)


@router.get("", response_model=list[IncidentResponse])
async def list_incidents(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """List all incidents ordered by most recent first."""
    incidents = await crud.list_incidents(db, skip=skip, limit=limit)
    return [IncidentResponse.from_orm_model(i) for i in incidents]


@router.get("/{incident_id}", response_model=IncidentResponse)
async def get_incident(
    incident_id: str,
    db: AsyncSession = Depends(get_db),
    _: str = Depends(verify_api_key),
):
    """Retrieve a single incident by ID."""
    obj = await crud.get_incident(db, incident_id)
    if not obj:
        raise HTTPException(status_code=404, detail="Incident not found")
    return IncidentResponse.from_orm_model(obj)
