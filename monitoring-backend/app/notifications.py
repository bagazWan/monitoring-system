"""
Simple notifications manager

Responsibilities:
- Manage WebSocket connections and broadcast alerts to connected clients.
- Provide a `notify_all_channels(payload)` helper that will:
    - Broadcast payload to connected WebSocket clients (best-effort).
    - Trigger placeholder FCM push notifications for registered device tokens.
    - Trigger placeholder email notifications for subscribed addresses.

Notes:
- This is an in-memory, single-process manager intended for development and
  small deployments. For multiple backend instances or production use, replace
  or augment the delivery channels with Redis pub/sub, a message queue, or a
  push notification service and persistent subscription storage.
- Placeholder FCM/email functions are provided and currently only log actions.
  Replace these with real provider integrations (async) and secure credential
  handling before production use.
"""

import asyncio
import logging
from typing import Any, Dict, List, Optional, Set

from fastapi import WebSocket

logger = logging.getLogger(__name__)


class ConnectionManager:
    """
    Manage WebSocket connections.

    Usage:
        manager = ConnectionManager()
        await manager.connect(websocket)
        await manager.broadcast({"type": "alert", "data": {...}})
    """

    def __init__(self) -> None:
        self._connections: Set[WebSocket] = set()
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket) -> None:
        """
        Accept and register a WebSocket connection.
        Call this from the WebSocket route after receive the webSocket instance
        """
        await websocket.accept()
        async with self._lock:
            self._connections.add(websocket)
            logger.debug(
                "WebSocket connected. Total connections=%d", len(self._connections)
            )

    async def disconnect(self, websocket: WebSocket) -> None:
        """
        Unregister a disconnecting WebSocket connection.
        """
        async with self._lock:
            if websocket in self._connections:
                self._connections.remove(websocket)
            logger.debug(
                "WebSocket disconnected. Total connections=%d", len(self._connections)
            )

    async def send_personal_message(
        self, websocket: WebSocket, message: Dict[str, Any]
    ) -> None:
        """
        Send a single JSON message to a single client. Exceptions are logged
        and cause that connection to be removed.
        """
        try:
            await websocket.send_json(message)
        except Exception:
            logger.exception("Failed to send websocket message; disconnecting client")
            await self.disconnect(websocket)

    async def broadcast(self, message: Dict[str, Any]) -> None:
        """
        Broadcast a message to all connected clients. This is best-effort:
        failures on individual connections do not stop the broadcast.
        """
        async with self._lock:
            connections = list(self._connections)

        if not connections:
            logger.debug("Broadcast called but no active websocket connections")
            return

        # Send concurrently to avoid slow clients blocking others
        coros = [self._safe_send(conn, message) for conn in connections]
        # Run the sends but don't raise on failures
        await asyncio.gather(*coros, return_exceptions=True)
        logger.debug("Broadcasted message to %d connections", len(connections))

    async def _safe_send(self, ws: WebSocket, message: Dict[str, Any]) -> None:
        try:
            await ws.send_json(message)
        except Exception:
            # If sending fails, disconnect the ws so future broadcasts don't try again
            logger.exception(
                "Error while sending websocket message; removing connection"
            )
            await self.disconnect(ws)


# single shared manager instance used by the rest of the app
manager = ConnectionManager()


# In-memory subscription registry for push tokens and email addresses.
# For production, store these in DB and support auth-based subscription management.
_fcm_tokens_by_user: Dict[Optional[int], Set[str]] = {}
_email_subscriptions_by_user: Dict[Optional[int], Set[str]] = {}

# A lock to protect the in-memory registries
_subs_lock = asyncio.Lock()


async def register_fcm_token(user_id: Optional[int], token: str) -> None:
    """
    Register a device token (FCM) for a user.
    user_id can be None to indicate a generic/topic subscription.
    """
    async with _subs_lock:
        tokens = _fcm_tokens_by_user.setdefault(user_id, set())
        tokens.add(token)
    logger.info("Registered FCM token for user=%s token=%s", user_id, token)


async def unregister_fcm_token(user_id: Optional[int], token: str) -> None:
    async with _subs_lock:
        tokens = _fcm_tokens_by_user.get(user_id)
        if tokens and token in tokens:
            tokens.remove(token)
    logger.info("Unregistered FCM token for user=%s token=%s", user_id, token)


async def register_email(user_id: Optional[int], email: str) -> None:
    async with _subs_lock:
        emails = _email_subscriptions_by_user.setdefault(user_id, set())
        emails.add(email)
    logger.info("Registered email for user=%s email=%s", user_id, email)


async def unregister_email(user_id: Optional[int], email: str) -> None:
    async with _subs_lock:
        emails = _email_subscriptions_by_user.get(user_id)
        if emails and email in emails:
            emails.remove(email)
    logger.info("Unregistered email for user=%s email=%s", user_id, email)


async def _send_fcm_push(token: str, payload: Dict[str, Any]) -> None:
    """
    Placeholder async FCM sender.

    Replace with a real implementation (firebase-admin, HTTP v1 API, or a server-side library)
    that sends notifications using credentials stored in environment variables or secret store.
    Implement exponential backoff and error handling for failed tokens.
    """
    # Best-effort: fire-and-forget simulated send
    try:
        # Example: log the intention. Replace with actual async HTTP request to FCM endpoint.
        logger.info("FCM send -> token=%s payload=%s", token, payload)
        # Simulate I/O latency for local testing (comment out in production)
        # await asyncio.sleep(0.01)
    except Exception:
        logger.exception("FCM send failed for token=%s", token)


async def _send_email_async(email: str, subject: str, body: str) -> None:
    """
    Placeholder async email sender.

    Replace with an async SMTP client or third-party email provider (SendGrid, SES).
    """
    try:
        logger.info("EMAIL send -> to=%s subject=%s body=%s", email, subject, body)
        # Simulate I/O latency for local testing (comment out in production)
        # await asyncio.sleep(0.01)
    except Exception:
        logger.exception("Email send failed for %s", email)


async def notify_all_channels(
    payload: Dict[str, Any], user_id: Optional[int] = None
) -> None:
    """
    Notify all configured channels about the given payload.

    - Broadcast to WebSocket clients (using the global `manager`)
    - Send FCM pushes to registered tokens for `user_id` and global (None)
    - Send emails to registered email addresses for `user_id` and global (None)

    This function is best-effort: failure in one channel does not prevent the others.
    It returns after scheduling or completing delivery attempts.
    """
    # 1) Broadcast via WebSocket (awaitable)
    try:
        # include a top-level type field if not provided
        msg = payload.copy()
        if "type" not in msg:
            msg.setdefault("type", "alert")
        await manager.broadcast(msg)
    except Exception:
        logger.exception("WebSocket broadcast failed for payload=%s", payload)

    # 2) Prepare push notifications (FCM)
    tokens_to_send: List[str] = []
    async with _subs_lock:
        # include global tokens subscribed with user_id=None
        tokens_to_send.extend(list(_fcm_tokens_by_user.get(None, set())))
        if user_id is not None:
            tokens_to_send.extend(list(_fcm_tokens_by_user.get(user_id, set())))

    if tokens_to_send:
        # send pushes concurrently
        push_coros = [_send_fcm_push(token, payload) for token in tokens_to_send]
        # schedule and await to keep ordering; if you prefer fire-and-forget use create_task
        try:
            await asyncio.gather(*push_coros, return_exceptions=True)
        except Exception:
            logger.exception("One or more FCM sends failed")

    # 3) Send emails
    emails_to_send: List[str] = []
    async with _subs_lock:
        emails_to_send.extend(list(_email_subscriptions_by_user.get(None, set())))
        if user_id is not None:
            emails_to_send.extend(
                list(_email_subscriptions_by_user.get(user_id, set()))
            )

    if emails_to_send:
        subject = f"[Monitoring] {payload.get('alert_type') or payload.get('type') or 'Alert'}"
        body = str(payload)
        email_coros = [
            _send_email_async(email, subject, body) for email in emails_to_send
        ]
        try:
            await asyncio.gather(*email_coros, return_exceptions=True)
        except Exception:
            logger.exception("One or more email sends failed")


async def websocket_endpoint(websocket: WebSocket) -> None:
    """
    WebSocket endpoint handler for real-time alert notifications.

    This function:
    1. Accepts the WebSocket connection
    2. Keeps connection alive (listens for client messages)
    3. Server broadcasts alerts via manager.broadcast()
    4. Disconnects cleanly when client closes connection
    """
    # Connect the websocket to manager
    await manager.connect(websocket)

    try:
        # Keep connection alive - listen for messages from client
        while True:
            # Wait for any message from client (or disconnect)
            data = await websocket.receive_text()

            # Optional: Handle client messages if needed
            # For now, we just ignore them since server pushes alerts
            logger.debug(f"Received message from client: {data}")

    except Exception as e:
        logger.info(f"WebSocket disconnected: {e}")
    finally:
        # Clean up
        await manager.disconnect(websocket)
