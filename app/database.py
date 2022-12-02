import os

import pydantic
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.orm.session import Session

SQLALCHEMY_DATABASE_URL = f"postgresql://{os.getenv('USER', 'postgres')}@postgresserver/db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


class Message(Base):
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True)
    message = Column(String)

class MessageSchema(pydantic.BaseModel):
    message: str


def create_message(db: Session, message: str):
    msg = Message(message=message)
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg

def get_messages(db: Session):
    return db.query(Message).all()
