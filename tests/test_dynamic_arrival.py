import pytest
from backend.app.services.recommendation_engine import RecommendationEngine, LAST_NOTIFIED_WAIT

def test_simulated_counter_down_event_emits_single_delay_event():
    booking_id = 99
    LAST_NOTIFIED_WAIT[booking_id] = 10.0 # Initial baseline wait: 10 minutes

    # 1. Normal minor queue change (10 min -> 15 min, diff = +5 min < 15 min threshold)
    # Should NOT emit delay notification event
    reasons_minor = ["Minor queue change: 1 extra farmer ahead."]
    emitted, event_obj = RecommendationEngine.check_and_emit_delay_event(
        booking_id=booking_id,
        new_predicted_wait=15.0,
        reasons=reasons_minor
    )
    assert emitted is False
    assert event_obj is None

    # 2. Simulated Counter-Down Event!
    # Wait increases from 10 min -> 45 min (+35 min diff >= 15 min threshold)
    # MUST emit EXACTLY ONE delay notification event!
    reasons_counter_down = ["1 counter went down unexpectedly.", "Queue wait increased significantly."]
    emitted, event_obj = RecommendationEngine.check_and_emit_delay_event(
        booking_id=booking_id,
        new_predicted_wait=45.0,
        reasons=reasons_counter_down
    )
    assert emitted is True
    assert event_obj is not None
    assert event_obj["event_type"] == "QUEUE_DELAY_ALERT"
    assert event_obj["variance_minutes"] == 35.0

    # 3. Duplicate trigger check with same wait time (45 min)
    # MUST NOT emit a duplicate event!
    emitted_dup, event_dup = RecommendationEngine.check_and_emit_delay_event(
        booking_id=booking_id,
        new_predicted_wait=45.0,
        reasons=reasons_counter_down
    )
    assert emitted_dup is False
    assert event_dup is None
