from __future__ import annotations

from datetime import datetime
from pydantic import BaseModel, EmailStr, Field

from .models import UserRole


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    role: UserRole


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)


class AuthResponse(BaseModel):
    token: str
    user_id: int
    name: str
    role: UserRole
    is_approved: bool
    work_point_id: int | None = None


class PerformerCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    specialization: str = Field(min_length=2, max_length=120)


class PerformerOut(BaseModel):
    id: int
    name: str
    specialization: str
    user_id: int | None = None


class EventCreate(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    description: str = ""
    category: str = Field(min_length=2, max_length=120)
    start_at: datetime
    end_at: datetime
    performer_ids: list[int] = []


class EventOut(BaseModel):
    id: int
    title: str
    description: str
    category: str
    start_at: datetime
    end_at: datetime
    performer_ids: list[int]
    performer_names: list[str]
    performer_user_ids: list[int]
    is_booked: bool
    booked_by_me: bool


class ServiceTypeCreate(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    category: str = Field(min_length=2, max_length=120)
    price: int = Field(ge=0)
    duration_minutes: int = Field(ge=5, le=1440)


class ServiceTypeOut(BaseModel):
    id: int
    title: str
    category: str
    price: int
    duration_minutes: int


class ProductCreate(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    category: str = Field(min_length=2, max_length=120)
    stock: int = Field(ge=0)
    price: int = Field(ge=0)


class ProductOut(BaseModel):
    id: int
    title: str
    category: str
    stock: int
    price: int


class WorkPointCreate(BaseModel):
    title: str = Field(min_length=2, max_length=160)
    address: str = Field(default="", max_length=255)


class WorkPointOut(BaseModel):
    id: int
    title: str
    address: str


class PendingPerformerOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    password: str
    created_at: datetime


class ApprovePerformerRequest(BaseModel):
    work_point_id: int


class StaffMemberOut(BaseModel):
    id: int
    name: str
    email: EmailStr
    password: str
    is_approved: bool
    work_point_id: int | None = None
    created_at: datetime


class BookingOut(BaseModel):
    id: int
    event_id: int
    created_at: datetime


class BookedUserOut(BaseModel):
    id: int
    name: str


class ChatMessageCreate(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class ChatMessageOut(BaseModel):
    id: int
    event_id: int
    author_id: int
    author_name: str
    text: str
    created_at: datetime
