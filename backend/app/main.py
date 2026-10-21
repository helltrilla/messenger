import os
import json
from typing import Dict, Set
from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Enable CORS for Flutter mobile, web, and local development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Static media uploads directory
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")


# --- WEBSOCKET CONNECTION MANAGER FOR TELEGRAM REALTIME ---
class ConnectionManager:
    def __init__(self):
        # user_id -> set of active WebSockets (handles multi-device)
        self.active_connections: Dict[str, Set[WebSocket]] = {}
        # chat_id -> set of user_ids in the chat
        self.chat_rooms: Dict[str, Set[str]] = {}

    async def connect(self, websocket: WebSocket, user_id: str):
        await websocket.accept()
        if user_id not in self.active_connections:
            self.active_connections[user_id] = set()
        self.active_connections[user_id].add(websocket)
        # Broadcast user online status
        await self.broadcast_user_status(user_id, is_online=True)

    def disconnect(self, websocket: WebSocket, user_id: str):
        if user_id in self.active_connections:
            self.active_connections[user_id].discard(websocket)
            if not self.active_connections[user_id]:
                del self.active_connections[user_id]

    async def send_to_user(self, user_id: str, data: dict):
        connections = self.active_connections.get(user_id, set())
        for ws in list(connections):
            try:
                await ws.send_text(json.dumps(data))
            except Exception:
                self.disconnect(ws, user_id)

    async def broadcast_to_chat(self, chat_id: str, member_ids: list[str], data: dict, exclude_sender: str = None):
        for uid in member_ids:
            if exclude_sender and uid == exclude_sender:
                continue
            await self.send_to_user(uid, data)

    async def broadcast_user_status(self, user_id: str, is_online: bool):
        payload = {
            "event": "user:presence",
            "data": {
                "user_id": user_id,
                "is_online": is_online,
            }
        }
        for uid in self.active_connections:
            if uid != user_id:
                await self.send_to_user(uid, payload)

manager = ConnectionManager()


@app.get("/")
def root():
    return {
        "status": "online",
        "app": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "docs": "/docs",
        "realtime_ws": "/ws/{user_id}",
    }


@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "messenger-backend"}


@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    await manager.connect(websocket, user_id)
    try:
        while True:
            text_data = await websocket.receive_text()
            try:
                msg = json.loads(text_data)
                event = msg.get("event")
                data = msg.get("data", {})

                # 1. Typing indicator ("печатает...")
                if event == "typing:start" or event == "typing:stop":
                    chat_id = data.get("chat_id")
                    recipients = data.get("recipients", [])
                    await manager.broadcast_to_chat(
                        chat_id=chat_id,
                        member_ids=recipients,
                        data={
                            "event": event,
                            "data": {
                                "chat_id": chat_id,
                                "user_id": user_id,
                                "is_typing": event == "typing:start"
                            }
                        },
                        exclude_sender=user_id,
                    )

                # 2. Realtime read receipt (Две галочки ✓✓)
                elif event == "message:read":
                    chat_id = data.get("chat_id")
                    message_id = data.get("message_id")
                    partner_id = data.get("partner_id")
                    if partner_id:
                        await manager.send_to_user(
                            partner_id,
                            {
                                "event": "message:read",
                                "data": {
                                    "chat_id": chat_id,
                                    "message_id": message_id,
                                    "read_by": user_id,
                                }
                            }
                        )

                # 3. Direct new message broadcast
                elif event == "message:send":
                    chat_id = data.get("chat_id")
                    recipients = data.get("recipients", [])
                    await manager.broadcast_to_chat(
                        chat_id=chat_id,
                        member_ids=recipients,
                        data={
                            "event": "message:new",
                            "data": data.get("message", {}),
                        },
                        exclude_sender=user_id,
                    )

            except json.JSONDecodeError:
                pass
    except WebSocketDisconnect:
        manager.disconnect(websocket, user_id)
        await manager.broadcast_user_status(user_id, is_online=False)
