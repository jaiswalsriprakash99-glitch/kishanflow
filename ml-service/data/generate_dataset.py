import os
import csv
import random

def generate_synthetic_dataset(filename: str = "ml-service/data/synthetic_dataset.csv", num_samples: int = 1000):
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    
    headers = [
        "centre_id", "crop_type", "quantity", "farmers_ahead", "current_queue_length",
        "active_counters", "staff_count", "staff_availability", "average_processing_time",
        "current_processing_speed", "time_of_day", "day_of_week", "seasonal_flag",
        "no_show_rate", "queue_growth_rate", "equipment_status", "operational_delay_flag",
        "actual_wait_minutes", "is_synthetic"
    ]

    crops = ["Paddy", "Wheat", "Maize", "Cotton", "Mustard"]

    rows = []
    for _ in range(num_samples):
        centre_id = random.randint(1, 10)
        crop_type = random.choice(crops)
        quantity = round(random.uniform(5.0, 60.0), 1)
        farmers_ahead = random.randint(0, 30)
        current_queue_length = farmers_ahead + random.randint(0, 10)
        active_counters = random.randint(1, 4)
        staff_count = active_counters + random.randint(0, 2)
        staff_availability = round(random.uniform(0.7, 1.0), 2)
        average_processing_time = round(random.uniform(10.0, 20.0), 1) # minutes per farmer
        current_processing_speed = round(random.uniform(0.8, 1.2), 2)
        time_of_day = random.randint(8, 17) # hour of day
        day_of_week = random.randint(0, 6)
        seasonal_flag = 1 if time_of_day in [10, 11, 14, 15] else 0
        no_show_rate = round(random.uniform(0.05, 0.20), 2)
        queue_growth_rate = round(random.uniform(-0.5, 1.5), 2)
        equipment_status = random.choice([1, 1, 1, 0]) # 1=OK, 0=Fault
        operational_delay_flag = 1 if equipment_status == 0 else 0

        # Realistic wait time calculation with noise
        base_wait = (farmers_ahead * average_processing_time) / (active_counters * current_processing_speed)
        delay_penalty = 25.0 if operational_delay_flag == 1 else 0.0
        noise = random.normalvariate(0, 3.0)
        actual_wait = max(3.0, round(base_wait + delay_penalty + noise, 1))

        rows.append([
            centre_id, crop_type, quantity, farmers_ahead, current_queue_length,
            active_counters, staff_count, staff_availability, average_processing_time,
            current_processing_speed, time_of_day, day_of_week, seasonal_flag,
            no_show_rate, queue_growth_rate, equipment_status, operational_delay_flag,
            actual_wait, True
        ])

    with open(filename, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(rows)

    print(f"Generated synthetic dataset with {num_samples} records at {filename}")

if __name__ == "__main__":
    generate_synthetic_dataset()
