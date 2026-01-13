import logging

from app.services.websocket_manager import ws_manager
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

logger = logging.getLogger(__name__)

router = APIRouter()


@router.websocket("/ws/status")
async def websocket_status_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for device status updates.

    Clients connect to this endpoint to receive:
    - status_change: When a device/switch status changes (online/offline)
    - heartbeat:  Periodic summary of system status

    Message format:
    {
        "type":  "status_change",
        "node_type": "device" | "switch",
        "id": int,
        "name": str,
        "ip_address":  str,
        "old_status": "online" | "offline",
        "new_status": "online" | "offline",
        "timestamp":  ISO8601 string
    }
    """
    await ws_manager.connect(websocket)

    try:
        # Send initial connection confirmation
        await ws_manager.send_personal_message(
            {
                "type": "connected",
                "message": "Connected to status updates",
            },
            websocket,
        )

        # Keep connection alive and handle incoming messages
        while True:
            try:
                # Wait for messages from client
                data = await websocket.receive_text()

                # Handle ping messages to keep connection alive
                if data == "ping":
                    await ws_manager.send_personal_message({"type": "pong"}, websocket)

            except WebSocketDisconnect:
                break

    except Exception as e:
        logger.error("WebSocket error: %s", e)
    finally:
        await ws_manager.disconnect(websocket)
