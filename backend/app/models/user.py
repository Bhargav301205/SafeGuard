import uuid
from sqlalchemy import String, JSON
from sqlalchemy.orm import Mapped, mapped_column
from pydantic import BaseModel, Field
from ..db.database import Base


# ── SQLAlchemy ORM Model ─────────────────────────────────────────────────────

class UserORM(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, nullable=False, default="")
    phone: Mapped[str] = mapped_column(String, nullable=False, default="")
    blood_group: Mapped[str] = mapped_column(String, default="")
    allergies: Mapped[str] = mapped_column(String, default="")
    medical_notes: Mapped[str] = mapped_column(String, default="")
    emergency_contacts: Mapped[list] = mapped_column(JSON, default=list)


# ── Pydantic Schemas ─────────────────────────────────────────────────────────

class UserProfileBase(BaseModel):
    name: str = ""
    phone: str = ""
    blood_group: str = ""
    allergies: str = ""
    medical_notes: str = ""
    emergency_contacts: list[str] = Field(default_factory=list)


class UserProfileCreate(UserProfileBase):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))


class UserProfileUpdate(UserProfileBase):
    pass


class UserProfileResponse(UserProfileBase):
    id: str

    model_config = {"from_attributes": True}
