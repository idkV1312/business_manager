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


class PerformerCreate(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    specialization: str = Field(min_length=2, max_length=120)


class PerformerOut(BaseModel):
    id: int
    name: str
    specialization: str


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


class BookingOut(BaseModel):
    id: int
    event_id: int
    created_at: datetime


class ChatMessageCreate(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class ChatMessageOut(BaseModel):
    id: int
    event_id: int
    author_id: int
    author_name: str
    text: str
    created_at: datetime
