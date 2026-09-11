import random
import datetime
from sqlalchemy.orm import Session
from backend.app.database import engine as default_engine, Base, SessionLocal
from backend.app.models import (
    Language, Farmer, FarmerProfile, PACS, ProcurementCentre, StaffUser,
    CentreCounter, Crop, Slot, Booking, QueueEntry, QueueEvent,
    ProcurementRecord, QualityCheck, Weighment, Payment, Notification,
    WeatherSnapshot, AppConfiguration, AIPrediction
)

def seed_database(db: Session):
    print("Starting KisanFlow Synthetic Data Seeding...")
    bind_engine = db.get_bind()
    Base.metadata.create_all(bind=bind_engine)

    # 1. Languages
    languages_data = [
        {"code": "en", "name": "English"},
        {"code": "hi", "name": "Hindi"},
        {"code": "kn", "name": "Kannada"},
        {"code": "mr", "name": "Marathi"},
        {"code": "te", "name": "Telugu"},
    ]
    lang_objs = []
    for l_data in languages_data:
        lang = db.query(Language).filter(Language.code == l_data["code"]).first()
        if not lang:
            lang = Language(**l_data)
            db.add(lang)
            db.flush()
        lang_objs.append(lang)

    # 2. PACS
    pacs_item = db.query(PACS).filter(PACS.code == "PACS_MYS_01").first()
    if not pacs_item:
        pacs_item = PACS(
            name="Mysore Primary Agricultural Credit Society",
            code="PACS_MYS_01",
            district="Mysore",
            state="Karnataka",
        )
        db.add(pacs_item)
        db.flush()

    # 3. Procurement Centres
    centres_data = [
        {
            "name": "Mandya District Main Mandi",
            "code": "MND_CENTRE_01",
            "centre_type": "GOVT_MANDI",
            "latitude": 12.5218,
            "longitude": 76.8951,
            "district": "Mandya",
            "state": "Karnataka",
            "address": "NH-275, Main Market Road, Mandya",
            "total_counters": 3,
        },
        {
            "name": "Mysore PACS Collection Point",
            "code": "MYS_PACS_01",
            "centre_type": "PACS",
            "latitude": 12.2958,
            "longitude": 76.6394,
            "district": "Mysore",
            "state": "Karnataka",
            "pacs_id": pacs_item.id,
            "address": "PACS Compound, Village Road, Mysore",
            "total_counters": 2,
        },
        {
            "name": "Hassan Sub-Procurement Hub",
            "code": "HSN_SUB_01",
            "centre_type": "PRIVATE_SUB",
            "latitude": 13.0033,
            "longitude": 76.1004,
            "district": "Hassan",
            "state": "Karnataka",
            "address": "Industrial Area, Phase 2, Hassan",
            "total_counters": 2,
        },
    ]
    centre_objs = []
    for c_data in centres_data:
        centre = db.query(ProcurementCentre).filter(ProcurementCentre.code == c_data["code"]).first()
        if not centre:
            centre = ProcurementCentre(**c_data)
            db.add(centre)
            db.flush()
        centre_objs.append(centre)

    # 3.5 Staff Users
    import bcrypt
    pwd_hash = bcrypt.hashpw(b"password123", bcrypt.gensalt()).decode('utf-8')
    staff_data = [
        {
            "username": "staff1",
            "full_name": "Mandya Staff Operator",
            "hashed_password": pwd_hash,
            "role": "CENTRE_STAFF",
            "centre_id": centre_objs[0].id,
            "phone_number": "9876540001",
        },
        {
            "username": "operator1",
            "full_name": "Mysore PACS Staff",
            "hashed_password": pwd_hash,
            "role": "CENTRE_STAFF",
            "centre_id": centre_objs[1].id,
            "phone_number": "9876540002",
        },
    ]
    for s_item in staff_data:
        staff_u = db.query(StaffUser).filter(StaffUser.username == s_item["username"]).first()
        if not staff_u:
            staff_u = StaffUser(**s_item)
            db.add(staff_u)
            db.flush()

    # 4. Counters
    counter_objs = []
    for centre in centre_objs:
        for i in range(1, centre.total_counters + 1):
            counter = db.query(CentreCounter).filter(
                CentreCounter.centre_id == centre.id,
                CentreCounter.counter_number == i
            ).first()
            if not counter:
                counter = CentreCounter(
                    centre_id=centre.id,
                    counter_number=i,
                    counter_name=f"Counter #{i}",
                    is_active=True
                )
                db.add(counter)
                db.flush()
            counter_objs.append(counter)

    # 5. Crops
    crops_data = [
        {"name": "Paddy", "code": "PDY", "msp_per_quintal": 2183.0, "unit": "Quintal", "season": "Kharif"},
        {"name": "Wheat", "code": "WHT", "msp_per_quintal": 2275.0, "unit": "Quintal", "season": "Rabi"},
        {"name": "Maize", "code": "MZE", "msp_per_quintal": 2090.0, "unit": "Quintal", "season": "Kharif"},
        {"name": "Cotton", "code": "CTN", "msp_per_quintal": 6620.0, "unit": "Quintal", "season": "Kharif"},
        {"name": "Mustard", "code": "MST", "msp_per_quintal": 5650.0, "unit": "Quintal", "season": "Rabi"},
    ]
    crop_objs = []
    for cr_data in crops_data:
        crop = db.query(Crop).filter(Crop.code == cr_data["code"]).first()
        if not crop:
            crop = Crop(**cr_data)
            db.add(crop)
            db.flush()
        crop_objs.append(crop)

    # 6. 50 Farmers with Profiles
    first_names = ["Ramesh", "Suresh", "Ganesh", "Mahesh", "Basavaraj", "Venkatesh", "Manjunath", "Shivakumar", "Nagendra", "Anand"]
    last_names = ["Gowda", "Patil", "Pujari", "Kumar", "Shetty", "Rao", "Naidu", "Hegde", "Reddy", "Kulkarni"]
    villages = ["Srirangapatna", "Maddur", "Pandavapura", "Nanjangud", "Hunsur", "TIRUMAKUDALU", "Channarayapatna", "Arsikere"]

    farmers_objs = []
    for i in range(1, 51):
        phone = f"98765432{i:02d}"
        farmer = db.query(Farmer).filter(Farmer.phone_number == phone).first()
        if not farmer:
            name = f"{random.choice(first_names)} {random.choice(last_names)}"
            pref_lang = random.choice(lang_objs)
            farmer = Farmer(
                phone_number=phone,
                full_name=name,
                preferred_language_id=pref_lang.id
            )
            db.add(farmer)
            db.flush()

            profile = FarmerProfile(
                farmer_id=farmer.id,
                father_name=f"Father of {name}",
                village=random.choice(villages),
                district="Mandya" if i <= 25 else "Mysore",
                state="Karnataka",
                pincode="571401",
                land_acreage=round(random.uniform(2.5, 15.0), 2),
                bank_account_no=f"5010023498{i:02d}",
                ifsc_code="SBIN0001234"
            )
            db.add(profile)
            db.flush()
        farmers_objs.append(farmer)

    # 7. Slots for past 7 days and next 7 days
    today = datetime.date.today()
    slot_objs = []
    for c in centre_objs:
        for cr in crop_objs:
            for day_offset in range(-7, 8):
                s_date = (today + datetime.timedelta(days=day_offset)).strftime("%Y-%m-%d")
                slot = db.query(Slot).filter(
                    Slot.centre_id == c.id,
                    Slot.crop_id == cr.id,
                    Slot.slot_date == s_date
                ).first()
                if not slot:
                    slot = Slot(
                        centre_id=c.id,
                        crop_id=cr.id,
                        slot_date=s_date,
                        start_time="09:00",
                        end_time="13:00",
                        capacity=25,
                        booked_count=0
                    )
                    db.add(slot)
                    db.flush()
                slot_objs.append(slot)

    # 8. Historical Bookings & Queue Records
    past_slots = [s for s in slot_objs if s.slot_date < today.strftime("%Y-%m-%d")]
    booking_counter = 1
    for idx, farmer in enumerate(farmers_objs):
        target_slot = past_slots[idx % len(past_slots)]
        booking_ref = f"SYNTH-BK-{booking_counter:04d}"
        existing_bk = db.query(Booking).filter(Booking.booking_reference == booking_ref).first()
        if not existing_bk:
            target_slot.booked_count += 1
            bk = Booking(
                booking_reference=booking_ref,
                farmer_id=farmer.id,
                slot_id=target_slot.id,
                centre_id=target_slot.centre_id,
                crop_id=target_slot.crop_id,
                estimated_quantity_quintals=round(random.uniform(10.0, 50.0), 1),
                queue_number=target_slot.booked_count,
                status="PROCUREMENT_COMPLETED",
                is_synthetic=True
            )
            db.add(bk)
            db.flush()

            actual_wait = random.randint(15, 85)
            q_entry = QueueEntry(
                booking_id=bk.id,
                centre_id=bk.centre_id,
                position=0,
                status="COMPLETED",
                actual_wait_minutes=float(actual_wait),
                check_in_time=datetime.datetime.utcnow() - datetime.timedelta(days=random.randint(1, 6)),
                service_start_time=datetime.datetime.utcnow() - datetime.timedelta(hours=2),
                service_end_time=datetime.datetime.utcnow() - datetime.timedelta(hours=1)
            )
            db.add(q_entry)
            db.flush()

            q_event = QueueEvent(
                queue_entry_id=q_entry.id,
                booking_id=bk.id,
                centre_id=bk.centre_id,
                event_type="COMPLETED",
                old_status="PROCESSING",
                new_status="COMPLETED",
                details_json="Completed processing synthetic seed historical booking"
            )
            db.add(q_event)

            # Seed AI Prediction record for historical accuracy evaluation
            predicted_wait = max(5.0, float(actual_wait + random.randint(-7, 7)))
            ai_pred = AIPrediction(
                booking_id=bk.id,
                centre_id=bk.centre_id,
                predicted_wait_minutes=predicted_wait,
                predicted_service_time_range="09:30-10:15 AM",
                recommended_arrival_time="09:15 AM",
                recommended_departure_time="10:15 AM",
                confidence_score=0.88,
                dominant_features_json='{"queue_length": 5, "active_counters": 2}'
            )
            db.add(ai_pred)

        booking_counter += 1

    # 9. App Configurations
    pacs_config = db.query(AppConfiguration).filter(AppConfiguration.key == "PACS_FORWARDING_REQUIRED").first()
    if not pacs_config:
        pacs_config = AppConfiguration(
            key="PACS_FORWARDING_REQUIRED",
            value="true",
            description="If true, PACS collections require forwarding to a main centre"
        )
        db.add(pacs_config)

    db.commit()
    print("Synthetic Data Seeding Completed Successfully!")

if __name__ == "__main__":
    db = SessionLocal()
    try:
        seed_database(db)
    finally:
        db.close()
