import asyncio
import json
import logging
from typing import Any, Dict, List, Set

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """
    Manages WebSocket connections and provides methods to broadcast messages.
    """

    def __init__(self):
        # Set of active WebSocket connections
        self.active_connections: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        """Accept a new WebSocket connection and add it to active connections"""
        await websocket.accept()
        async with self._lock:
            self.active_connections.add(websocket)
        logger.info(
            "WebSocket client connected.  Total connections: %d",
            len(self.active_connections),
        )

    async def disconnect(self, websocket: WebSocket) -> None:
        """Remove a WebSocket connection from active connections"""
        async with self._lock:
            self.active_connections.discard(websocket)
        logger.info(
            "WebSocket client disconnected. Total connections: %d",
            len(self.active_connections),
        )

    async def broadcast(self, message: Dict[str, Any]) -> None:
        """
        Broadcast a message to all connected clients.
        Automatically removes disconnected clients
        """
        if not self.active_connections:
            return

        message_json = json.dumps(message)
        disconnected: List[WebSocket] = []

        async with self._lock:
            connections = list(self.active_connections)

        for connection in connections:
            try:
                await connection.send_text(message_json)
            except Exception as e:
                logger.warning("Failed to send message to client: %s", e)
                disconnected.append(connection)

        # Clean up disconnected clients
        if disconnected:
            async with self._lock:
                for conn in disconnected:
                    self.active_connections.discard(conn)

    async def send_personal_message(
        self, message: Dict[str, Any], websocket: WebSocket
    ) -> None:
        """Send a message to a specific client"""
        try:
            await websocket.send_text(json.dumps(message))
        except Exception as e:
            logger.warning("Failed to send personal message: %s", e)

    @property
    def connection_count(self) -> int:
        """Return the number of active connections."""
        return len(self.active_connections)


# Global singleton instance
ws_manager = ConnectionManager()
