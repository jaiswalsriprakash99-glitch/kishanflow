from typing import List, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from backend.app.database import get_db
from backend.app.routers.auth import decode_jwt_token
from backend.app.models import QueueEntry, Booking
from backend.app.ws.connection_manager import manager

router = APIRouter(tags=["WebSocket Real-Time Queue Updates"])

class QueueResyncItem(BaseModel):
    booking_id: int
    booking_reference: str
    position: int
    status: str
    counter_id: Optional[int] = None

class QueueResyncResponse(BaseModel):
    centre_id: int
    active_queue: List[QueueResyncItem]

@router.websocket("/ws/centre/{centre_id}")
async def websocket_centre_endpoint(
    websocket: WebSocket,
    centre_id: int,
    token: Optional[str] = Query(None)
):
    if not token:
        await websocket.close(code=4001, reason="Missing authentication token")
        return

    try:
        payload = decode_jwt_token(token)
    except Exception:
        await websocket.close(code=4001, reason="Invalid or expired authentication token")
        return

    await manager.connect(centre_id, websocket)
    try:
        while True:
            # Keep connection alive & listen for client ping
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text(json.dumps({"event": "pong"}))
    except WebSocketDisconnect:
        manager.disconnect(centre_id, websocket)
    except Exception:
        manager.disconnect(centre_id, websocket)

@router.get("/queue/resync/{centre_id}", response_model=QueueResyncResponse)
def resync_queue(centre_id: int, db: Session = Depends(get_db)):
    entries = db.query(QueueEntry).filter(
        QueueEntry.centre_id == centre_id,
        QueueEntry.status.in_(["WAITING", "PROCESSING"])
    ).order_by(QueueEntry.position.asc()).all()

    items = []
    for e in entries:
        b = db.query(Booking).filter(Booking.id == e.booking_id).first()
        items.append(QueueResyncItem(
            booking_id=e.booking_id,
            booking_reference=b.booking_reference if b else f"BK-{e.booking_id}",
            position=e.position,
            status=e.status,
            counter_id=e.counter_id
        ))

    return QueueResyncResponse(
        centre_id=centre_id,
        active_queue=items
    )
