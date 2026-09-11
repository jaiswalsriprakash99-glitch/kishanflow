import json
import datetime
from typing import Optional, Dict, List
from sqlalchemy.orm import Session
from backend.app.models import QueueEntry, QueueEvent, Booking, ProcurementCentre, StaffUser

class QueueEngine:
    @staticmethod
    def recalculate_positions(db: Session, centre_id: int):
        db.flush()
        waiting_entries = db.query(QueueEntry).filter(
            QueueEntry.centre_id == centre_id,
            QueueEntry.status == "WAITING"
        ).order_by(QueueEntry.id.asc()).all()

        for idx, entry in enumerate(waiting_entries, start=1):
            entry.position = idx

        db.flush()

    @staticmethod
    def arrive_farmer(db: Session, booking_id: int) -> QueueEntry:
        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if not booking:
            raise ValueError("Booking not found")

        existing_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
        now = datetime.datetime.utcnow()

        if not existing_entry:
            current_max_pos = db.query(QueueEntry).filter(
                QueueEntry.centre_id == booking.centre_id,
                QueueEntry.status == "WAITING"
            ).count()

            q_entry = QueueEntry(
                booking_id=booking.id,
                centre_id=booking.centre_id,
                position=current_max_pos + 1,
                status="WAITING",
                check_in_time=now
            )
            db.add(q_entry)
            db.flush()

            booking.status = "ARRIVED"

            q_event = QueueEvent(
                queue_entry_id=q_entry.id,
                booking_id=booking.id,
                centre_id=booking.centre_id,
                event_type="ARRIVED",
                old_status=None,
                new_status="WAITING",
                details_json=json.dumps({"queue_number": booking.queue_number, "position": q_entry.position})
            )
            db.add(q_event)
            QueueEngine.recalculate_positions(db, booking.centre_id)
            return q_entry
        else:
            return existing_entry

    @staticmethod
    def start_service(db: Session, booking_id: int, counter_id: int, staff_id: Optional[int] = None) -> QueueEntry:
        q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
        if not q_entry:
            raise ValueError("Queue entry not found")

        old_status = q_entry.status
        now = datetime.datetime.utcnow()

        q_entry.status = "PROCESSING"
        q_entry.counter_id = counter_id
        q_entry.service_start_time = now
        q_entry.position = 0

        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if booking:
            booking.status = "IN_QUEUE"

        q_event = QueueEvent(
            queue_entry_id=q_entry.id,
            booking_id=q_entry.booking_id,
            centre_id=q_entry.centre_id,
            event_type="START",
            old_status=old_status,
            new_status="PROCESSING",
            triggered_by_staff_id=staff_id,
            details_json=json.dumps({"counter_id": counter_id})
        )
        db.add(q_event)
        QueueEngine.recalculate_positions(db, q_entry.centre_id)
        return q_entry

    @staticmethod
    def complete_service(db: Session, booking_id: int, staff_id: Optional[int] = None) -> QueueEntry:
        q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
        if not q_entry:
            raise ValueError("Queue entry not found")

        old_status = q_entry.status
        now = datetime.datetime.utcnow()

        q_entry.status = "COMPLETED"
        q_entry.service_end_time = now
        q_entry.position = 0

        if q_entry.check_in_time:
            wait_seconds = (now - q_entry.check_in_time).total_seconds()
            q_entry.actual_wait_minutes = round(wait_seconds / 60.0, 1)
        else:
            q_entry.actual_wait_minutes = 15.0

        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if booking:
            booking.status = "VERIFICATION"

        q_event = QueueEvent(
            queue_entry_id=q_entry.id,
            booking_id=q_entry.booking_id,
            centre_id=q_entry.centre_id,
            event_type="COMPLETED",
            old_status=old_status,
            new_status="COMPLETED",
            triggered_by_staff_id=staff_id,
            details_json=json.dumps({"actual_wait_minutes": q_entry.actual_wait_minutes})
        )
        db.add(q_event)
        QueueEngine.recalculate_positions(db, q_entry.centre_id)
        return q_entry

    @staticmethod
    def skip_farmer(db: Session, booking_id: int, staff_id: Optional[int] = None) -> QueueEntry:
        q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
        if not q_entry:
            raise ValueError("Queue entry not found")

        old_status = q_entry.status
        q_entry.status = "SKIPPED"
        q_entry.position = 0

        q_event = QueueEvent(
            queue_entry_id=q_entry.id,
            booking_id=q_entry.booking_id,
            centre_id=q_entry.centre_id,
            event_type="SKIPPED",
            old_status=old_status,
            new_status="SKIPPED",
            triggered_by_staff_id=staff_id
        )
        db.add(q_event)
        QueueEngine.recalculate_positions(db, q_entry.centre_id)
        return q_entry

    @staticmethod
    def no_show_farmer(db: Session, booking_id: int, staff_id: Optional[int] = None) -> QueueEntry:
        q_entry = db.query(QueueEntry).filter(QueueEntry.booking_id == booking_id).first()
        if not q_entry:
            raise ValueError("Queue entry not found")

        old_status = q_entry.status
        q_entry.status = "NO_SHOW"
        q_entry.position = 0

        booking = db.query(Booking).filter(Booking.id == booking_id).first()
        if booking:
            booking.status = "CANCELLED"

        q_event = QueueEvent(
            queue_entry_id=q_entry.id,
            booking_id=q_entry.booking_id,
            centre_id=q_entry.centre_id,
            event_type="NO_SHOW",
            old_status=old_status,
            new_status="NO_SHOW",
            triggered_by_staff_id=staff_id
        )
        db.add(q_event)
        QueueEngine.recalculate_positions(db, q_entry.centre_id)
        return q_entry
