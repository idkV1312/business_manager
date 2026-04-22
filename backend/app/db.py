import os
import sqlite3
import tempfile
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

def _resolve_database_url() -> str:
    from_env = os.getenv("DATABASE_URL")
    if from_env:
        return from_env

    candidates = [
        Path(__file__).resolve().parent.parent / "app.db",
        Path(tempfile.gettempdir()) / "business_manager_app.db",
    ]

    for path in candidates:
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with sqlite3.connect(path.as_posix()) as conn:
                conn.execute("PRAGMA journal_mode=WAL")
                conn.execute("CREATE TABLE IF NOT EXISTS __db_probe__(id INTEGER PRIMARY KEY)")
                conn.execute("DROP TABLE IF EXISTS __db_probe__")
                conn.commit()
            return f"sqlite:///{path.as_posix()}"
        except Exception:
            continue

    return "sqlite:///:memory:"


DATABASE_URL = _resolve_database_url()

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, class_=Session)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
