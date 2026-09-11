import pytest
from backend.app.services.locale_templates import render_notification_template, SMS_TEMPLATES

def test_sms_template_rendering_in_multiple_locales():
    sample_data = {
        "farmer_name": "Ramesh Gowda",
        "booking_ref": "BK-MND-001",
        "centre_name": "Mandya District Mandi",
        "slot_time": "09:00 AM - 11:00 AM",
        "queue_number": 5,
        "wait_minutes": 25,
        "rec_departure": "08:35 AM",
        "amount": "45,000",
        "status": "ACCEPTED"
    }

    # 1. English Locale Rendering
    rendered_en = render_notification_template("QUEUE_DELAY_ALERT", "en", sample_data)
    assert "Ramesh Gowda" in rendered_en
    assert "25 minutes" in rendered_en
    assert "08:35 AM" in rendered_en

    # 2. Hindi Locale Rendering
    rendered_hi = render_notification_template("QUEUE_DELAY_ALERT", "hi", sample_data)
    assert "नमस्ते Ramesh Gowda" in rendered_hi
    assert "25 मिनट" in rendered_hi
    assert "08:35 AM" in rendered_hi

    # 3. Kannada Locale Rendering
    rendered_kn = render_notification_template("BOOKING_CREATED", "kn", sample_data)
    assert "Ramesh Gowda" in rendered_kn or "ಬುಕಿಂಗ್ ಖಚಿತವಾಗಿದೆ" in rendered_kn
    assert "BK-MND-001" in rendered_kn

    # 4. Marathi Locale Rendering
    rendered_mr = render_notification_template("RECOMMENDED_DEPARTURE", "mr", sample_data)
    assert "निघण्याची वेळ" in rendered_mr

    # 5. Telugu Locale Rendering
    rendered_te = render_notification_template("PAYMENT_STATUS_CHANGED", "te", sample_data)
    assert "₹45,000" in rendered_te
