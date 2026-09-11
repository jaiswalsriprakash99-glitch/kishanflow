import os
import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import train_test_split
from sklearn.metrics import mean_absolute_error
from ml_service.data.generate_dataset import generate_synthetic_dataset

def train_wait_time_model(csv_path: str = "ml-service/data/synthetic_dataset.csv", model_path: str = "ml-service/models/wait_time_model.pkl"):
    if not os.path.exists(csv_path):
        generate_synthetic_dataset(csv_path)

    df = pd.read_csv(csv_path)

    feature_cols = [
        "quantity", "farmers_ahead", "current_queue_length", "active_counters",
        "staff_count", "staff_availability", "average_processing_time",
        "current_processing_speed", "time_of_day", "day_of_week", "seasonal_flag",
        "no_show_rate", "queue_growth_rate", "equipment_status", "operational_delay_flag"
    ]

    X = df[feature_cols]
    y = df["actual_wait_minutes"]

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = RandomForestRegressor(n_estimators=100, max_depth=12, random_state=42)
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    mae = mean_absolute_error(y_test, y_pred)
    print(f"Model Training Complete. Test MAE: {mae:.2f} minutes")

    os.makedirs(os.path.dirname(model_path), exist_ok=True)
    joblib.dump({"model": model, "feature_cols": feature_cols, "mae": mae}, model_path)
    print(f"Saved model to {model_path}")
    return mae

if __name__ == "__main__":
    train_wait_time_model()
