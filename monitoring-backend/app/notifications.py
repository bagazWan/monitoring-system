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

from app.services.websocket_manager import ws_manager

logger = logging.getLogger(__name__)

# In-memory subscription registry for push tokens and email addresses.
# For production, store these in DB and support auth-based subscription management.
_fcm_tokens_by_user: Dict[Optional[int], Set[str]] = {}
_email_subscriptions_by_user: Dict[Optional[int], Set[str]] = {}

# A lock to protect the in-memory registries
_subs_lock = asyncio.Lock()


async def register_fcm_token(user_id: Optional[int], token: str) -> None:
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
    try:
        logger.info("FCM send -> token=%s payload=%s", token, payload)
    except Exception:
        logger.exception("FCM send failed for token=%s", token)


async def _send_email_async(email: str, subject: str, body: str) -> None:
    try:
        logger.info("EMAIL send -> to=%s subject=%s body=%s", email, subject, body)
    except Exception:
        logger.exception("Email send failed for %s", email)


async def notify_all_channels(
    payload: Dict[str, Any], user_id: Optional[int] = None
) -> None:
    """
    Notify all configured channels about the given payload.

    - Broadcast to ALL connected websocket clients via ws_manager (unified ws)
    - Placeholder: send FCM + email
    """
    # 1. WebSocket broadcast
    try:
        msg = payload.copy()
        msg.setdefault("type", "alert")
        await ws_manager.broadcast(msg)
    except Exception:
        logger.exception("WebSocket broadcast failed for payload=%s", payload)

    # 2. FCM pushes (placeholder)
    tokens_to_send: List[str] = []
    async with _subs_lock:
        tokens_to_send.extend(list(_fcm_tokens_by_user.get(None, set())))
        if user_id is not None:
            tokens_to_send.extend(list(_fcm_tokens_by_user.get(user_id, set())))

    if tokens_to_send:
        try:
            await asyncio.gather(
                *[_send_fcm_push(token, payload) for token in tokens_to_send],
                return_exceptions=True,
            )
        except Exception:
            logger.exception("One or more FCM sends failed")

    # 3. Emails (placeholder)
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
        try:
            await asyncio.gather(
                *[_send_email_async(email, subject, body) for email in emails_to_send],
                return_exceptions=True,
            )
        except Exception:
            logger.exception("One or more email sends failed")
