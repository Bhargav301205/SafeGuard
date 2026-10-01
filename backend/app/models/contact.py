import uuid
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column
from pydantic import BaseModel, EmailStr, Field, model_validator
from ..db.database import Base


# ── SQLAlchemy ORM Model ─────────────────────────────────────────────────────

class ContactORM(Base):
    __tablename__ = "contacts"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String, nullable=False)
    email: Mapped[str] = mapped_column(String, nullable=False, default="")
    phone: Mapped[str] = mapped_column(String, nullable=False, default="")  # kept for migration
    relation: Mapped[str] = mapped_column(String, default="")


# ── Pydantic Schemas ─────────────────────────────────────────────────────────

class ContactCreate(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    email: str = ""   # primary — used for email alerts
    phone: str = ""   # legacy fallback
    relation: str = ""

    @model_validator(mode="after")
    def sync_email_and_phone(self) -> "ContactCreate":
        """If email is blank but phone is provided, use phone as fallback, and vice versa."""
        if not self.email and self.phone:
            self.email = self.phone
        elif not self.phone and self.email:
            self.phone = self.email
        return self


class ContactResponse(BaseModel):
    id: str
    name: str
    email: str = ""
    phone: str = ""
    relation: str

    model_config = {"from_attributes": True}
