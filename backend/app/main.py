from __future__ import annotations

import json
from collections import defaultdict

from fastapi import Depends, FastAPI, HTTPException, WebSocket, WebSocketDisconnect, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text, select
from sqlalchemy.orm import Session

from .auth import (
    DEFAULT_ADMIN_EMAIL,
    create_access_token,
    ensure_default_admin,
    get_current_user,
    hash_password,
    require_admin,
    verify_password,
)
from .db import SessionLocal, engine, get_db
from .models import (
    Base,
    Booking,
    ChatMessage,
    DirectChatMessage,
    Event,
    EventPerformer,
    Performer,
    Product,
    ServiceType,
    User,
    UserRole,
    WorkPoint,
)
from .schemas import (
    ApprovePerformerRequest,
    AuthResponse,
    BookedUserOut,
    BookingOut,
    ChatMessageCreate,
    ChatMessageOut,
    EventCreate,
    EventOut,
    LoginRequest,
    ProductCreate,
    ProductOut,
    PendingPerformerOut,
    PerformerCreate,
    PerformerOut,
    RegisterRequest,
    ServiceTypeCreate,
    ServiceTypeOut,
    StaffMemberOut,
    WorkPointCreate,
    WorkPointOut,
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


def _run_sqlite_bootstrap_migrations() -> None:
    if not str(engine.url).startswith("sqlite"):
        return
    with engine.begin() as conn:
        cols = conn.execute(text("PRAGMA table_info(users)")).fetchall()
        names = {row[1] for row in cols}
        if "is_approved" not in names:
            conn.execute(text("ALTER TABLE users ADD COLUMN is_approved BOOLEAN NOT NULL DEFAULT 1"))
        if "work_point_id" not in names:
            conn.execute(text("ALTER TABLE users ADD COLUMN work_point_id INTEGER"))
        if "plain_password" not in names:
            conn.execute(text("ALTER TABLE users ADD COLUMN plain_password VARCHAR(128)"))


_run_sqlite_bootstrap_migrations()
with SessionLocal() as _db:
    ensure_default_admin(_db)


def event_to_out(event: Event, db: Session, viewer: User | None = None) -> EventOut:
    performer_ids = [ep.performer_id for ep in event.performers]
    names: list[str] = []
    performer_user_ids: list[int] = []
    if performer_ids:
        performers = db.scalars(select(Performer).where(Performer.id.in_(performer_ids))).all()
        names = [p.name for p in performers]
        performer_user_ids = [p.created_by_admin_id for p in performers]
    booking = db.scalar(select(Booking).where(Booking.event_id == event.id).order_by(Booking.created_at.asc()))
    is_booked = booking is not None
    booked_by_me = viewer is not None and booking is not None and booking.user_id == viewer.id
    return EventOut(
        id=event.id,
        title=event.title,
        description=event.description,
        category=event.category,
        start_at=event.start_at,
        end_at=event.end_at,
        performer_ids=performer_ids,
        performer_names=names,
        performer_user_ids=performer_user_ids,
        is_booked=is_booked,
        booked_by_me=booked_by_me,
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


def direct_message_to_out(message: DirectChatMessage, db: Session) -> ChatMessageOut:
    user = db.get(User, message.author_id)
    return ChatMessageOut(
        id=message.id,
        event_id=message.event_id,
        author_id=message.author_id,
        author_name=user.name if user else "Unknown",
        text=message.text,
        created_at=message.created_at,
    )


def resolve_direct_chat_user_id(
    event: Event,
    actor: User,
    db: Session,
    requested_user_id: int | None = None,
) -> int:
    if actor.role == UserRole.user:
        booking = db.scalar(select(Booking).where(Booking.user_id == actor.id, Booking.event_id == event.id))
        if not booking:
            raise HTTPException(status_code=403, detail="Booking is required for direct chat")
        return actor.id

    if actor.role == UserRole.admin:
        if event.created_by_admin_id != actor.id:
            raise HTTPException(status_code=403, detail="Direct chat allowed only for your own events")
        if requested_user_id is not None:
            booking = db.scalar(
                select(Booking).where(Booking.user_id == requested_user_id, Booking.event_id == event.id)
            )
            if not booking:
                raise HTTPException(status_code=404, detail="User booking not found for this event")
            return requested_user_id
        first_booking = db.scalar(
            select(Booking).where(Booking.event_id == event.id).order_by(Booking.created_at.asc())
        )
        if not first_booking:
            raise HTTPException(status_code=404, detail="No booked users for this event")
        return first_booking.user_id

    raise HTTPException(status_code=403, detail="Direct chat is available only for admin and user")


def service_to_out(service: ServiceType) -> ServiceTypeOut:
    return ServiceTypeOut(
        id=service.id,
        title=service.title,
        category=service.category,
        price=service.price,
        duration_minutes=service.duration_minutes,
    )


def product_to_out(product: Product) -> ProductOut:
    return ProductOut(
        id=product.id,
        title=product.title,
        category=product.category,
        stock=product.stock,
        price=product.price,
    )


@app.get("/health")
def healthcheck() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/auth/register", response_model=AuthResponse)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    if payload.role == UserRole.admin:
        raise HTTPException(status_code=403, detail="Admin registration is disabled")

    existing = db.scalar(select(User).where(User.email == payload.email.lower()))
    if existing:
        raise HTTPException(status_code=400, detail="Email already exists")

    is_approved = payload.role == UserRole.user

    user = User(
        name=payload.name,
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        plain_password=payload.password,
        role=payload.role,
        is_approved=is_approved,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    if user.role == UserRole.performer and not user.is_approved:
        return JSONResponse(
            status_code=202,
            content={"detail": "Сотрудник зарегистрирован и ожидает подтверждения администратором"},
        )

    token = create_access_token(user.id, user.role)
    return AuthResponse(
        token=token,
        user_id=user.id,
        name=user.name,
        role=user.role,
        is_approved=user.is_approved,
        work_point_id=user.work_point_id,
    )


@app.post("/auth/login", response_model=AuthResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.email == payload.email.lower()))
    if not user or not verify_password(payload.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if user.role == UserRole.admin and user.email.lower() != DEFAULT_ADMIN_EMAIL.lower():
        raise HTTPException(status_code=403, detail="Admin access is disabled for this account")
    if user.role == UserRole.performer and not user.is_approved:
        raise HTTPException(
            status_code=403,
            detail="Регистрация сотрудника ожидает подтверждения администратором",
        )

    token = create_access_token(user.id, user.role)
    return AuthResponse(
        token=token,
        user_id=user.id,
        name=user.name,
        role=user.role,
        is_approved=user.is_approved,
        work_point_id=user.work_point_id,
    )


@app.get("/work-points", response_model=list[WorkPointOut])
def list_work_points(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    work_points = db.scalars(select(WorkPoint).order_by(WorkPoint.title.asc())).all()
    return [WorkPointOut(id=wp.id, title=wp.title, address=wp.address) for wp in work_points]


@app.post("/work-points", response_model=WorkPointOut)
def create_work_point(
    payload: WorkPointCreate,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    work_point = WorkPoint(title=payload.title, address=payload.address)
    db.add(work_point)
    db.commit()
    db.refresh(work_point)
    return WorkPointOut(id=work_point.id, title=work_point.title, address=work_point.address)


@app.get("/staff/pending", response_model=list[PendingPerformerOut])
def list_pending_staff(
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    rows = db.scalars(
        select(User)
        .where(User.role == UserRole.performer, User.is_approved.is_(False))
        .order_by(User.created_at.asc())
    ).all()
    return [
        PendingPerformerOut(
            id=user.id,
            name=user.name,
            email=user.email,
            password=user.plain_password or "",
            created_at=user.created_at,
        )
        for user in rows
    ]


@app.get("/staff", response_model=list[StaffMemberOut])
def list_staff(
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    rows = db.scalars(
        select(User).where(User.role == UserRole.performer).order_by(User.created_at.desc())
    ).all()
    return [
        StaffMemberOut(
            id=user.id,
            name=user.name,
            email=user.email,
            password=user.plain_password or "",
            is_approved=user.is_approved,
            work_point_id=user.work_point_id,
            created_at=user.created_at,
        )
        for user in rows
    ]


@app.post("/staff/{user_id}/approve", response_model=PerformerOut)
def approve_staff_member(
    user_id: int,
    payload: ApprovePerformerRequest,
    _: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    user = db.get(User, user_id)
    if not user or user.role != UserRole.performer:
        raise HTTPException(status_code=404, detail="Performer not found")
    work_point = db.get(WorkPoint, payload.work_point_id)
    if not work_point:
        raise HTTPException(status_code=404, detail="Work point not found")

    user.is_approved = True
    user.work_point_id = work_point.id

    existing = db.scalar(select(Performer).where(Performer.created_by_admin_id == user.id))
    if not existing:
        performer = Performer(
            name=user.name,
            specialization="Специалист",
            created_by_admin_id=user.id,
        )
        db.add(performer)
        db.flush()
    else:
        performer = existing

    db.commit()
    db.refresh(performer)
    return PerformerOut(
        id=performer.id,
        name=performer.name,
        specialization=performer.specialization,
        user_id=performer.created_by_admin_id,
    )


@app.get("/performers", response_model=list[PerformerOut])
def list_performers(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    performers = db.scalars(select(Performer).order_by(Performer.id.desc())).all()
    return [
        PerformerOut(id=p.id, name=p.name, specialization=p.specialization, user_id=p.created_by_admin_id)
        for p in performers
    ]


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
    return PerformerOut(
        id=performer.id,
        name=performer.name,
        specialization=performer.specialization,
        user_id=performer.created_by_admin_id,
    )


@app.get("/events", response_model=list[EventOut])
def list_events(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    events = db.scalars(select(Event).order_by(Event.start_at.asc())).all()
    out = [event_to_out(event, db, viewer=user) for event in events]
    if user.role == UserRole.user:
        return [item for item in out if not item.is_booked or item.booked_by_me]
    return out


@app.get("/services", response_model=list[ServiceTypeOut])
def list_services(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    services = db.scalars(select(ServiceType).order_by(ServiceType.title.asc())).all()
    return [service_to_out(service) for service in services]


@app.post("/services", response_model=ServiceTypeOut)
def create_service(
    payload: ServiceTypeCreate,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    service = ServiceType(
        title=payload.title,
        category=payload.category,
        price=payload.price,
        duration_minutes=payload.duration_minutes,
        created_by_admin_id=admin.id,
    )
    db.add(service)
    db.commit()
    db.refresh(service)
    return service_to_out(service)


@app.get("/products", response_model=list[ProductOut])
def list_products(
    _: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    products = db.scalars(select(Product).order_by(Product.title.asc())).all()
    return [product_to_out(product) for product in products]


@app.post("/products", response_model=ProductOut)
def create_product(
    payload: ProductCreate,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    product = Product(
        title=payload.title,
        category=payload.category,
        stock=payload.stock,
        price=payload.price,
        created_by_admin_id=admin.id,
    )
    db.add(product)
    db.commit()
    db.refresh(product)
    return product_to_out(product)


@app.post("/events", response_model=EventOut)
def create_event(
    payload: EventCreate,
    actor: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if actor.role not in {UserRole.admin, UserRole.performer}:
        raise HTTPException(status_code=403, detail="Only admin or performer can create slots")
    if payload.end_at <= payload.start_at:
        raise HTTPException(status_code=400, detail="end_at must be later than start_at")

    performer_ids = list(payload.performer_ids)
    if actor.role == UserRole.performer:
        performer = db.scalar(select(Performer).where(Performer.created_by_admin_id == actor.id))
        if performer is None:
            performer = Performer(
                name=actor.name,
                specialization="Специалист",
                created_by_admin_id=actor.id,
            )
            db.add(performer)
            db.flush()
        performer_ids = [performer.id]
    if actor.role == UserRole.admin and not performer_ids:
        raise HTTPException(status_code=400, detail="At least one performer is required")

    event = Event(
        title=payload.title,
        description=payload.description,
        category=payload.category,
        start_at=payload.start_at,
        end_at=payload.end_at,
        created_by_admin_id=actor.id,
    )
    db.add(event)
    db.flush()

    for performer_id in performer_ids:
        performer = db.get(Performer, performer_id)
        if performer:
            db.add(EventPerformer(event_id=event.id, performer_id=performer_id))

    db.commit()
    db.refresh(event)
    return event_to_out(event, db, viewer=actor)


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

    existing = db.scalar(select(Booking).where(Booking.event_id == event_id).order_by(Booking.created_at.asc()))
    if existing:
        if existing.user_id == user.id:
            return BookingOut(id=existing.id, event_id=existing.event_id, created_at=existing.created_at)
        raise HTTPException(status_code=409, detail="This time slot is already booked")

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


@app.get("/events/{event_id}/booked-users", response_model=list[BookedUserOut])
def list_booked_users_for_event(
    event_id: int,
    admin: User = Depends(require_admin),
    db: Session = Depends(get_db),
):
    event = db.get(Event, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    if event.created_by_admin_id != admin.id:
        raise HTTPException(status_code=403, detail="Access denied for this event")
    bookings = db.scalars(select(Booking).where(Booking.event_id == event_id).order_by(Booking.created_at.asc())).all()
    user_ids = list(dict.fromkeys([booking.user_id for booking in bookings]))
    if not user_ids:
        return []
    users = db.scalars(select(User).where(User.id.in_(user_ids))).all()
    users_by_id = {user.id: user for user in users}
    return [BookedUserOut(id=user_id, name=users_by_id[user_id].name) for user_id in user_ids if user_id in users_by_id]


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


@app.get("/events/{event_id}/direct-chat", response_model=list[ChatMessageOut])
def get_direct_chat(
    event_id: int,
    user_id: int | None = None,
    actor: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.get(Event, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    participant_user_id = resolve_direct_chat_user_id(event, actor, db, requested_user_id=user_id)
    messages = db.scalars(
        select(DirectChatMessage)
        .where(DirectChatMessage.event_id == event_id, DirectChatMessage.user_id == participant_user_id)
        .order_by(DirectChatMessage.created_at.asc())
    ).all()
    return [direct_message_to_out(message, db) for message in messages]


@app.post("/events/{event_id}/direct-chat", response_model=ChatMessageOut)
def send_direct_chat_message(
    event_id: int,
    payload: ChatMessageCreate,
    user_id: int | None = None,
    actor: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    event = db.get(Event, event_id)
    if not event:
        raise HTTPException(status_code=404, detail="Event not found")
    participant_user_id = resolve_direct_chat_user_id(event, actor, db, requested_user_id=user_id)
    message = DirectChatMessage(
        event_id=event_id,
        user_id=participant_user_id,
        author_id=actor.id,
        text=payload.text,
    )
    db.add(message)
    db.commit()
    db.refresh(message)
    return direct_message_to_out(message, db)


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
