import os
import time
import logging
import datetime
from typing import Dict, Any, Optional
from sqlalchemy.orm import Session
from backend.app.config import get_settings
from backend.app.models import Notification, Farmer, Language

logger = logging.getLogger("kissanflow.notifications")

class FCMPushService:
    @staticmethod
    def send_push_notification(device_token: str, title: str, body: str) -> bool:
        settings = get_settings()
        api_key = settings.FCM_SERVER_KEY
        if not api_key:
            logger.warning("FCM_SERVER_KEY not configured in environment")
            return False

        # Simulate FCM push send with backoff retries
        for attempt in range(1, 4):
            try:
                # Simulated FCM delivery logic
                logger.info(f"[FCM PUSH] Attempt {attempt} to {device_token}: '{title}' - '{body}'")
                return True
            except Exception as e:
                logger.error(f"[FCM PUSH ERROR] Attempt {attempt} failed: {e}")
                time.sleep(0.1 * (2 ** attempt))
        return False

class IndianSMSService:
    @staticmethod
    def send_sms(phone_number: str, message: str) -> bool:
        settings = get_settings()
        api_key = settings.SMS_API_KEY
        if not api_key:
            logger.warning("SMS_API_KEY not configured in environment")
            return False

        for attempt in range(1, 4):
            try:
                logger.info(f"[INDIAN SMS] Attempt {attempt} to {phone_number}: '{message}'")
                return True
            except Exception as e:
                logger.error(f"[INDIAN SMS ERROR] Attempt {attempt} failed: {e}")
                time.sleep(0.1 * (2 ** attempt))
        return False

class NotificationManager:
    @staticmethod
    def dispatch_event(
        event_type: str,
        farmer_id: int,
        phone_number: str,
        title: str,
        message: str,
        device_token: Optional[str] = "mock_fcm_token_123",
        db: Optional[Session] = None,
        preferred_language_code: str = "hi"
    ) -> Dict[str, bool]:
        # Determine primary channel based on blueprint rules
        # SMS primary for QUEUE_DELAY_ALERT and RECOMMENDED_DEPARTURE
        if event_type in ["QUEUE_DELAY_ALERT", "RECOMMENDED_DEPARTURE"]:
            primary_channel = "SMS"
        else:
            primary_channel = "PUSH"

        results = {"push_sent": False, "sms_sent": False}
        errors = []

        if primary_channel == "SMS":
            # Primary: SMS
            try:
                results["sms_sent"] = IndianSMSService.send_sms(phone_number, message)
            except Exception as e:
                errors.append(f"SMS Error: {str(e)}")

            # Fallback/Secondary: PUSH
            try:
                results["push_sent"] = FCMPushService.send_push_notification(device_token or "mock_fcm_token", title, message)
            except Exception as e:
                errors.append(f"PUSH Error: {str(e)}")
        else:
            # Primary: PUSH
            try:
                results["push_sent"] = FCMPushService.send_push_notification(device_token or "mock_fcm_token", title, message)
            except Exception as e:
                errors.append(f"PUSH Error: {str(e)}")

            # Secondary: SMS
            try:
                results["sms_sent"] = IndianSMSService.send_sms(phone_number, message)
            except Exception as e:
                errors.append(f"SMS Error: {str(e)}")

        # Audit log in database if session available
        if db:
            status_str = "SENT" if (results["push_sent"] or results["sms_sent"]) else "FAILED"
            notif_row = Notification(
                farmer_id=farmer_id,
                title=title,
                message=message,
                channel=primary_channel,
                template_locale=preferred_language_code,
                status=status_str,
                sent_at=datetime.datetime.utcnow(),
                error_log="; ".join(errors) if errors else None
            )
            db.add(notif_row)
            try:
                db.commit()
            except Exception:
                db.rollback()

        return results
