import pytest
from backend.app.services.notifications import NotificationManager, FCMPushService, IndianSMSService
from backend.app.database import Base
from backend.app.models import Notification, Farmer, Language
from tests.conftest import test_engine, TestingSessionLocal

@pytest.fixture(autouse=True)
def setup_notif_db():
    Base.metadata.create_all(bind=test_engine)
    yield

def test_channel_mapping_rules():
    db = TestingSessionLocal()
    try:
        phone = "9888800001"
        farmer = db.query(Farmer).filter(Farmer.phone_number == phone).first()
        if not farmer:
            farmer = Farmer(phone_number=phone, full_name="Notif Farmer 1")
            db.add(farmer)
            db.commit()
            db.refresh(farmer)

        res_delay = NotificationManager.dispatch_event(
            event_type="QUEUE_DELAY_ALERT",
            farmer_id=farmer.id,
            phone_number=farmer.phone_number,
            title="Queue Delay Notice",
            message="Your queue wait increased by 20 minutes.",
            db=db
        )
        assert res_delay["sms_sent"] is True

        notif_row = db.query(Notification).filter(Notification.title == "Queue Delay Notice").first()
        assert notif_row is not None
        assert notif_row.channel == "SMS"

        res_bk = NotificationManager.dispatch_event(
            event_type="BOOKING_CREATED",
            farmer_id=farmer.id,
            phone_number=farmer.phone_number,
            title="Booking Confirmed",
            message="Your slot booking is confirmed.",
            db=db
        )
        assert res_bk["push_sent"] is True
        notif_bk = db.query(Notification).filter(Notification.title == "Booking Confirmed").first()
        assert notif_bk.channel == "PUSH"
    finally:
        db.close()

def test_fcm_failure_does_not_block_sms_delivery(monkeypatch):
    def mock_push_failure(*args, **kwargs):
        raise RuntimeError("FCM Service Unavailable")

    monkeypatch.setattr(FCMPushService, "send_push_notification", mock_push_failure)

    db = TestingSessionLocal()
    try:
        phone = "9888800002"
        farmer = db.query(Farmer).filter(Farmer.phone_number == phone).first()
        if not farmer:
            farmer = Farmer(phone_number=phone, full_name="Resilient Farmer")
            db.add(farmer)
            db.commit()

        res = NotificationManager.dispatch_event(
            event_type="PAYMENT_STATUS_CHANGED",
            farmer_id=farmer.id,
            phone_number=farmer.phone_number,
            title="Payment Credited",
            message="Rs 45,000 credited to bank.",
            db=db
        )

        assert res["sms_sent"] is True
        assert res["push_sent"] is False
    finally:
        db.close()
