from __future__ import annotations

import json
from collections import defaultdict

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from .auth import create_access_token, get_current_user, hash_password, require_admin, verify_password
from .db import SessionLocal, engine, get_db
from .models import Base, Booking, ChatMessage, Event, EventPerformer, Performer, User, UserRole
from .schemas import (
    AuthResponse,
    BookingOut,
    ChatMessageCreate,
    ChatMessageOut,
    EventCreate,
    EventOut,
    LoginRequest,
    PerformerCreate,
    PerformerOut,
    RegisterRequest,
)

app = FastAPI(title="Business Manager API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

Base.metadata.create_all(bind=engine)

connections: dict[int, set[WebSocket]] = defaultdict(set)


def event_to_out(event: Event, db: Session) -> EventOut:
    performer_ids = [ep.performer_id for ep in event.performers]
    names: list[str] = []
    if performer_ids:
        performers = db.scalars(select(Performer).where(Performer.id.in_(performer_ids))).all()
        names = [p.name for p in performers]
    return EventOut(
        id=event.id,
        title=event.title,
        description=event.description,
        category=event.category,
        start_at=event.start_at,
        end_at=event.end_at,
        performer_ids=performer_ids,
        performer_names=names,
    )


def message_to_out(message: ChatMessage, db: Session) -> ChatMessageOut:
    user = db.get(User, message.author_id)
    return ChatMessageOut(
        id=message.id,
        event_id=message.event_id,
        author_id=message.author_id,
        author_name=user.name if user else "Unknown",
        text=message.text,
        created_at=message.created_at,
    )


@app.get("/health")
def healthcheck() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/register", response_model=AuthResponse)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.scalar(select(User).where(User.email == payload.email.lower()))
    if existing:
        raise HTTPException(status_code=400, detail="Email already exists")

    user = User(
        name=payload.name,
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        role=payload.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(user.id, user.role)
    return AuthResponse(token=token, user_id=user.id, name=user.name, role=user.role)


@app.post("/auth/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token(user.id, user.role)
    return AuthResponse(token=token, user_id=user.id, name=user.name, role=user.role)


@app.get("/performers", response_model=list[PerformerOut])
def list_performers(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    performers = db.scalars(select(Performer).order_by(Performer.id.desc())).all()
    return [PerformerOut(id=p.id, name=p.name, specialization=p.specialization) for p in performers]


@app.post("/performers", response_model=PerformerOut)
def create_performer(
    payload: PerformerCreate,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    performer = Performer(
        name=payload.name,
        specialization=payload.specialization,
        created_by_admin_id=admin.id,
    )
    db.add(performer)
    db.commit()
    db.refresh(performer)
    return PerformerOut(id=performer.id, name=performer.name, specialization=performer.specialization)


@app.get("/events", response_model=list[EventOut])
def list_events(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    events = db.scalars(select(Event).order_by(Event.start_at.asc())).all()
    return [event_to_out(event, db) for event in events]


@app.post("/events", response_model=EventOut)
def create_event(
    payload: EventCreate,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    if payload.end_at <= payload.start_at:
        raise HTTPException(status_code=400, detail="end_at must be later than start_at")

    event = Event(
        title=payload.title,
        description=payload.description,
        category=payload.category,
        start_at=payload.start_at,
        end_at=payload.end_at,
        created_by_admin_id=admin.id,
    )
    db.add(event)
    db.flush()

    for performer_id in payload.performer_ids:
        performer = db.get(Performer, performer_id)
        if performer:
            db.add(EventPerformer(event_id=event.id, performer_id=performer_id))

    db.commit()
    db.refresh(event)
    return event_to_out(event, db)


@app.post("/events/{event_id}/book", response_model=BookingOut)
def book_event(
    event_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.role != UserRole.user:
        raise HTTPException(status_code=403, detail="Only users can book events")

    event = db.get(Event, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    existing = db.scalar(
        select(Booking).where(Booking.user_id == user.id, Booking.event_id == event_id)
    )
    if existing:
        return BookingOut(id=existing.id, event_id=existing.event_id, created_at=existing.created_at)

    booking = Booking(user_id=user.id, event_id=event_id)
    db.add(booking)
    db.commit()
    db.refresh(booking)
    return BookingOut(id=booking.id, event_id=booking.event_id, created_at=booking.created_at)


@app.get("/me/bookings", response_model=list[BookingOut])
def my_bookings(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    rows = db.scalars(select(Booking).where(Booking.user_id == user.id).order_by(Booking.created_at.desc())).all()
    return [BookingOut(id=b.id, event_id=b.event_id, created_at=b.created_at) for b in rows]


@app.get("/events/{event_id}/chat", response_model=list[ChatMessageOut])
def get_chat(
    event_id: int,
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    messages = db.scalars(
        select(ChatMessage).where(ChatMessage.event_id == event_id).order_by(ChatMessage.created_at.asc())
    ).all()
    return [message_to_out(message, db) for message in messages]


@app.post("/events/{event_id}/chat", response_model=ChatMessageOut)
async def send_chat_message(
    event_id: int,
    payload: ChatMessageCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.get(Event, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")

    message = ChatMessage(event_id=event_id, author_id=user.id, text=payload.text)
    db.add(message)
    db.commit()
    db.refresh(message)

    result = message_to_out(message, db)
    await broadcast(event_id, result.model_dump(mode="json"))
    return result


async def broadcast(event_id: int, payload: dict):
    stale: list[WebSocket] = []
    for socket in connections[event_id]:
        try:
            await socket.send_text(json.dumps(payload, ensure_ascii=False, default=str))
        except Exception:
            stale.append(socket)
    for socket in stale:
        connections[event_id].discard(socket)


@app.websocket("/ws/events/{event_id}/chat")
async def chat_socket(websocket: WebSocket, event_id: int, token: str):
    from .auth import decode_token

    try:
        payload = decode_token(token)
        user_id = int(payload.get("sub"))
    except Exception:
        await websocket.close(code=1008)
        return

    await websocket.accept()
    connections[event_id].add(websocket)
    try:
        while True:
            raw = await websocket.receive_text()
            text = raw.strip()
            if not text:
                continue
            # Save websocket messages as chat entries to keep one message stream.
            with SessionLocal() as db:
                message = ChatMessage(event_id=event_id, author_id=user_id, text=text)
                db.add(message)
                db.commit()
                db.refresh(message)
                out = message_to_out(message, db)
            await broadcast(event_id, out.model_dump(mode="json"))
    except WebSocketDisconnect:
        connections[event_id].discard(websocket)
    except Exception:
        connections[event_id].discard(websocket)
        await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
