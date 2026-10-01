import uuid
from datetime import datetime
from typing import Optional
from sqlalchemy import String, Float, Boolean, JSON, DateTime
from sqlalchemy.orm import Mapped, mapped_column
from pydantic import BaseModel, Field
from ..db.database import Base


# ── SQLAlchemy ORM Model ─────────────────────────────────────────────────────

class IncidentORM(Base):
    __tablename__ = "incidents"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    timestamp: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    lat: Mapped[float] = mapped_column(Float, nullable=False)
    lng: Mapped[float] = mapped_column(Float, nullable=False)
    address: Mapped[str] = mapped_column(String, default="")
    status: Mapped[str] = mapped_column(String, default="pending")  # pending | confirmed | cancelled
    sensor_snapshot: Mapped[dict] = mapped_column(JSON, default=dict)
    contacts_notified: Mapped[list] = mapped_column(JSON, default=list)
    emergency_call_placed: Mapped[bool] = mapped_column(Boolean, default=False)


# ── Pydantic Schemas ─────────────────────────────────────────────────────────

class SensorSnapshotSchema(BaseModel):
    gForce: float
    rotationRate: Optional[float] = None
    speedDelta: Optional[float] = None
    timestamp: str


class IncidentCreate(BaseModel):
    id: Optional[str] = Field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: Optional[str] = None
    lat: float
    lng: float
    address: str = ""
    status: str = "pending"
    sensorSnapshot: SensorSnapshotSchema
    contactsNotified: list[str] = []
    emergencyCallPlaced: bool = False


class IncidentResponse(BaseModel):
    id: str
    timestamp: str
    lat: float
    lng: float
    address: str
    status: str
    sensorSnapshot: dict
    contactsNotified: list[str]
    emergencyCallPlaced: bool
    mapsUrl: str

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_model(cls, obj: IncidentORM) -> "IncidentResponse":
        return cls(
            id=obj.id,
            timestamp=obj.timestamp.isoformat(),
            lat=obj.lat,
            lng=obj.lng,
            address=obj.address,
            status=obj.status,
            sensorSnapshot=obj.sensor_snapshot,
            contactsNotified=obj.contacts_notified,
            emergencyCallPlaced=obj.emergency_call_placed,
            mapsUrl=f"https://maps.google.com/?q={obj.lat},{obj.lng}",
        )
