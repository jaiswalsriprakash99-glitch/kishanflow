import datetime
from sqlalchemy import (
    Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Text,
    UniqueConstraint, Index
)
from sqlalchemy.orm import relationship
from backend.app.database import Base

class Language(Base):
    __tablename__ = "languages"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(10), unique=True, nullable=False, index=True)
    name = Column(String(50), nullable=False)

class Farmer(Base):
    __tablename__ = "farmers"

    id = Column(Integer, primary_key=True, index=True)
    phone_number = Column(String(15), unique=True, nullable=False, index=True)
    full_name = Column(String(100), nullable=False)
    preferred_language_id = Column(Integer, ForeignKey("languages.id"), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    profile = relationship("FarmerProfile", back_populates="farmer", uselist=False)
    language = relationship("Language")

class FarmerProfile(Base):
    __tablename__ = "farmer_profiles"

    id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), unique=True, nullable=False)
    father_name = Column(String(100), nullable=True)
    village = Column(String(100), nullable=True)
    district = Column(String(100), nullable=True)
    state = Column(String(100), nullable=True)
    pincode = Column(String(10), nullable=True)
    land_acreage = Column(Float, default=0.0)
    bank_account_no = Column(String(30), nullable=True)
    ifsc_code = Column(String(20), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    farmer = relationship("Farmer", back_populates="profile")

class PACS(Base):
    __tablename__ = "pacs"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    code = Column(String(50), unique=True, nullable=False, index=True)
    district = Column(String(100), nullable=False)
    state = Column(String(100), nullable=False)
    pacs_operator_id = Column(Integer, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class ProcurementCentre(Base):
    __tablename__ = "procurement_centres"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(150), nullable=False)
    code = Column(String(50), unique=True, nullable=False, index=True)
    centre_type = Column(String(50), nullable=False, default="GOVT_MANDI") # GOVT_MANDI, PACS, PRIVATE_SUB
    latitude = Column(Float, nullable=False)
    longitude = Column(Float, nullable=False)
    pacs_id = Column(Integer, ForeignKey("pacs.id"), nullable=True)
    address = Column(Text, nullable=True)
    district = Column(String(100), nullable=False)
    state = Column(String(100), nullable=False)
    is_active = Column(Boolean, default=True)
    total_counters = Column(Integer, default=2)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    pacs = relationship("PACS")
    counters = relationship("CentreCounter", back_populates="centre")

class StaffUser(Base):
    __tablename__ = "staff_users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    full_name = Column(String(100), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(String(50), nullable=False, default="CENTRE_STAFF") # FARMER, CENTRE_STAFF, PACS_OPERATOR, ADMIN, SUPER_ADMIN
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=True)
    phone_number = Column(String(15), nullable=True)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    centre = relationship("ProcurementCentre")

class CentreCounter(Base):
    __tablename__ = "centre_counters"

    id = Column(Integer, primary_key=True, index=True)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    counter_number = Column(Integer, nullable=False)
    counter_name = Column(String(50), nullable=False)
    is_active = Column(Boolean, default=True)
    assigned_staff_id = Column(Integer, ForeignKey("staff_users.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    centre = relationship("ProcurementCentre", back_populates="counters")
    assigned_staff = relationship("StaffUser")

class Crop(Base):
    __tablename__ = "crops"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, nullable=False, index=True)
    code = Column(String(20), nullable=False)
    msp_per_quintal = Column(Float, nullable=False)
    unit = Column(String(20), default="Quintal")
    season = Column(String(50), default="Kharif")

class Slot(Base):
    __tablename__ = "slots"

    id = Column(Integer, primary_key=True, index=True)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    crop_id = Column(Integer, ForeignKey("crops.id"), nullable=False)
    slot_date = Column(String(10), nullable=False) # YYYY-MM-DD
    start_time = Column(String(5), nullable=False) # HH:MM
    end_time = Column(String(5), nullable=False)   # HH:MM
    capacity = Column(Integer, nullable=False, default=20)
    booked_count = Column(Integer, nullable=False, default=0)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    centre = relationship("ProcurementCentre")
    crop = relationship("Crop")

class Booking(Base):
    __tablename__ = "bookings"

    id = Column(Integer, primary_key=True, index=True)
    booking_reference = Column(String(50), unique=True, nullable=False, index=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    slot_id = Column(Integer, ForeignKey("slots.id"), nullable=False, index=True)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    crop_id = Column(Integer, ForeignKey("crops.id"), nullable=False)
    estimated_quantity_quintals = Column(Float, nullable=False)
    queue_number = Column(Integer, nullable=False)
    status = Column(String(50), nullable=False, default="REGISTERED")
    qr_code_token = Column(String(100), nullable=True)
    is_synthetic = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    __table_args__ = (
        UniqueConstraint("farmer_id", "slot_id", name="uq_farmer_slot"),
        Index("idx_booking_slot_id", "slot_id"),
    )

    farmer = relationship("Farmer")
    slot = relationship("Slot")
    centre = relationship("ProcurementCentre")
    crop = relationship("Crop")

class QueueEntry(Base):
    __tablename__ = "queue_entries"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), unique=True, nullable=False)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    position = Column(Integer, nullable=False)
    status = Column(String(50), nullable=False, default="WAITING") # WAITING, CALLED, PROCESSING, COMPLETED, SKIPPED, NO_SHOW
    counter_id = Column(Integer, ForeignKey("centre_counters.id"), nullable=True)
    check_in_time = Column(DateTime, nullable=True)
    service_start_time = Column(DateTime, nullable=True)
    service_end_time = Column(DateTime, nullable=True)
    actual_wait_minutes = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    __table_args__ = (
        Index("idx_queue_entries_centre_position", "centre_id", "position"),
    )

    booking = relationship("Booking")
    centre = relationship("ProcurementCentre")
    counter = relationship("CentreCounter")

class QueueEvent(Base):
    __tablename__ = "queue_events"

    id = Column(Integer, primary_key=True, index=True)
    queue_entry_id = Column(Integer, ForeignKey("queue_entries.id"), nullable=False)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    event_type = Column(String(50), nullable=False)
    old_status = Column(String(50), nullable=True)
    new_status = Column(String(50), nullable=False)
    triggered_by_staff_id = Column(Integer, ForeignKey("staff_users.id"), nullable=True)
    details_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class ProcurementRecord(Base):
    __tablename__ = "procurement_records"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), unique=True, nullable=False)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    crop_id = Column(Integer, ForeignKey("crops.id"), nullable=False)
    quantity_quintals = Column(Float, nullable=False)
    total_amount = Column(Float, nullable=False)
    status = Column(String(50), nullable=False, default="ACCEPTED")
    pacs_id = Column(Integer, ForeignKey("pacs.id"), nullable=True)
    is_forwarded = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class QualityCheck(Base):
    __tablename__ = "quality_checks"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    inspector_id = Column(Integer, ForeignKey("staff_users.id"), nullable=True)
    moisture_content_percent = Column(Float, nullable=False)
    foreign_matter_percent = Column(Float, nullable=False)
    broken_grains_percent = Column(Float, nullable=False)
    grade = Column(String(20), default="Grade A")
    passed = Column(Boolean, nullable=False, default=True)
    rejection_reason = Column(String(255), nullable=True)
    inspected_at = Column(DateTime, default=datetime.datetime.utcnow)

class Weighment(Base):
    __tablename__ = "weighments"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    weighbridge_operator_id = Column(Integer, ForeignKey("staff_users.id"), nullable=True)
    gross_weight_kg = Column(Float, nullable=False)
    tare_weight_kg = Column(Float, nullable=False)
    net_weight_kg = Column(Float, nullable=False)
    bags_count = Column(Integer, nullable=False)
    weighed_at = Column(DateTime, default=datetime.datetime.utcnow)

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    procurement_record_id = Column(Integer, ForeignKey("procurement_records.id"), nullable=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    amount = Column(Float, nullable=False)
    payment_reference = Column(String(100), nullable=False)
    status = Column(String(50), nullable=False, default="INITIATED")
    is_simulated = Column(Boolean, default=True)
    initiated_at = Column(DateTime, default=datetime.datetime.utcnow)
    credited_at = Column(DateTime, nullable=True)

class Notification(Base):
    __tablename__ = "notifications"

    id = Column(Integer, primary_key=True, index=True)
    farmer_id = Column(Integer, ForeignKey("farmers.id"), nullable=False)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=True)
    title = Column(String(150), nullable=False)
    message = Column(Text, nullable=False)
    channel = Column(String(20), nullable=False, default="PUSH")
    template_locale = Column(String(10), default="hi")
    status = Column(String(20), default="SENT")
    sent_at = Column(DateTime, default=datetime.datetime.utcnow)
    error_log = Column(Text, nullable=True)

class WeatherSnapshot(Base):
    __tablename__ = "weather_snapshots"

    id = Column(Integer, primary_key=True, index=True)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    temperature_celsius = Column(Float, nullable=False)
    humidity_percent = Column(Float, nullable=False)
    rainfall_mm = Column(Float, default=0.0)
    weather_condition = Column(String(50), default="Clear")
    risk_level = Column(String(20), default="LOW")
    risk_summary = Column(String(255), nullable=True)
    fetched_at = Column(DateTime, default=datetime.datetime.utcnow)

class VehicleCost(Base):
    __tablename__ = "vehicle_costs"

    id = Column(Integer, primary_key=True, index=True)
    vehicle_type = Column(String(50), nullable=False)
    base_rate_per_km = Column(Float, nullable=False)
    capacity_quintals = Column(Float, nullable=False)
    fuel_surcharge_per_km = Column(Float, default=0.0)

class AIPrediction(Base):
    __tablename__ = "ai_predictions"

    id = Column(Integer, primary_key=True, index=True)
    booking_id = Column(Integer, ForeignKey("bookings.id"), nullable=False)
    centre_id = Column(Integer, ForeignKey("procurement_centres.id"), nullable=False)
    predicted_wait_minutes = Column(Float, nullable=False)
    predicted_service_time_range = Column(String(50), nullable=True)
    recommended_arrival_time = Column(String(30), nullable=True)
    recommended_departure_time = Column(String(30), nullable=True)
    confidence_score = Column(Float, default=0.85)
    dominant_features_json = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

class AuditLog(Base):
    __tablename__ = "audit_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=True)
    user_role = Column(String(50), nullable=True)
    action = Column(String(100), nullable=False)
    resource = Column(String(100), nullable=False)
    resource_id = Column(String(50), nullable=True)
    details_json = Column(Text, nullable=True)
    ip_address = Column(String(50), nullable=True)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

class AppConfiguration(Base):
    __tablename__ = "app_configurations"

    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(100), unique=True, nullable=False, index=True)
    value = Column(Text, nullable=False)
    description = Column(String(255), nullable=True)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)
