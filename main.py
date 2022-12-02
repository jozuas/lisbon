import typing as t

from fastapi import Depends, FastAPI
from sqlalchemy.orm import Session

from app import database

database.Base.metadata.create_all(bind=database.engine)
app = FastAPI()

# Dependency
def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/")
def read_item():
    return {}

@app.post("/messages/", response_model=database.MessageSchema)
def post_message(message: database.MessageSchema, db: Session = Depends(get_db)):
    return database.create_message(db=db, message=message.message)


@app.get("/messages/", response_model=t.List[database.MessageSchema])
def get_messages(db: Session = Depends(get_db)):
    return database.get_messages(db)
