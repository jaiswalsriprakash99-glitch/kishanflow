import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from backend.app.config import get_settings

def create_db_engine(db_url: str = None):
    if db_url is None:
        settings = get_settings()
        db_url = settings.DATABASE_URL

    connect_args = {}
    if db_url.startswith("sqlite"):
        connect_args = {"check_same_thread": False}

    engine = create_engine(db_url, connect_args=connect_args)
    return engine

# Default engine & SessionLocal
default_settings = get_settings()
engine = create_db_engine(default_settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
