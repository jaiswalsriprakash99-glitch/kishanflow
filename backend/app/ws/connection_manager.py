import json
import asyncio
from typing import Dict, List
from fastapi import WebSocket

class ConnectionManager:
    def __init__(self):
        # Maps centre_id -> List of active WebSockets
        self.active_connections: Dict[int, List[WebSocket]] = {}

    async def connect(self, centre_id: int, websocket: WebSocket):
        await websocket.accept()
        if centre_id not in self.active_connections:
            self.active_connections[centre_id] = []
        self.active_connections[centre_id].append(websocket)

    def disconnect(self, centre_id: int, websocket: WebSocket):
        if centre_id in self.active_connections:
            if websocket in self.active_connections[centre_id]:
                self.active_connections[centre_id].remove(websocket)
            if not self.active_connections[centre_id]:
                del self.active_connections[centre_id]

    async def broadcast_queue_update(self, centre_id: int, message_data: dict):
        if centre_id in self.active_connections:
            disconnected = []
            message_text = json.dumps(message_data)
            for ws in self.active_connections[centre_id]:
                try:
                    await ws.send_text(message_text)
                except Exception:
                    disconnected.append(ws)

            for ws in disconnected:
                self.disconnect(centre_id, ws)

manager = ConnectionManager()
