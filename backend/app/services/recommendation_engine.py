import datetime
from typing import Dict, Any, List, Tuple, Optional

LAST_NOTIFIED_WAIT = {}

class RecommendationEngine:
    @staticmethod
    def generate_recommendations(
        predicted_wait_minutes: float,
        slot_start_time: str = "09:00",
        travel_time_minutes: float = 25.0,
        farmers_ahead: int = 0,
        active_counters: int = 2,
        operational_delay_flag: int = 0
    ) -> Dict[str, Any]:
        reasons = []
        if farmers_ahead > 5:
            reasons.append(f"High queue volume: {farmers_ahead} farmers ahead in line.")
        elif farmers_ahead == 0:
            reasons.append("No waiting queue currently.")
        else:
            reasons.append(f"Moderate queue: {farmers_ahead} farmers ahead.")

        if active_counters <= 1:
            reasons.append("Only 1 counter currently operating.")
        else:
            reasons.append(f"{active_counters} counters currently active.")

        if operational_delay_flag == 1:
            reasons.append("Equipment maintenance / operational delay active at centre.")

        try:
            today_str = datetime.date.today().strftime("%Y-%m-%d")
            base_time = datetime.datetime.strptime(f"{today_str} {slot_start_time}", "%Y-%m-%d %H:%M")
        except Exception:
            base_time = datetime.datetime.now().replace(hour=9, minute=0, second=0)

        est_service_start = base_time + datetime.timedelta(minutes=predicted_wait_minutes)
        est_service_end = est_service_start + datetime.timedelta(minutes=15)

        service_range_str = f"{est_service_start.strftime('%I:%M %p')} - {est_service_end.strftime('%I:%M %p')}"
        rec_arrival = max(base_time, est_service_start - datetime.timedelta(minutes=10))
        rec_arrival_str = rec_arrival.strftime("%I:%M %p")
        rec_departure = rec_arrival - datetime.timedelta(minutes=travel_time_minutes)
        rec_departure_str = rec_departure.strftime("%I:%M %p")

        return {
            "predicted_service_time_range": service_range_str,
            "recommended_arrival_time": rec_arrival_str,
            "recommended_departure_time": rec_departure_str,
            "reasons": reasons
        }

    @staticmethod
    def check_and_emit_delay_event(
        booking_id: int,
        new_predicted_wait: float,
        reasons: List[str]
    ) -> Tuple[bool, Optional[Dict[str, Any]]]:
        last_wait = LAST_NOTIFIED_WAIT.get(booking_id, 0.0)

        diff = new_predicted_wait - last_wait
        if abs(diff) >= 15.0:
            LAST_NOTIFIED_WAIT[booking_id] = new_predicted_wait

            event_obj = {
                "booking_id": booking_id,
                "event_type": "QUEUE_DELAY_ALERT" if diff > 0 else "QUEUE_SPEEDUP_ALERT",
                "old_wait_minutes": last_wait,
                "new_wait_minutes": new_predicted_wait,
                "variance_minutes": round(diff, 1),
                "reasons": reasons,
                "timestamp": datetime.datetime.utcnow().isoformat()
            }
            return True, event_obj

        return False, None
