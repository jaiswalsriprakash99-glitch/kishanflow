import os
import joblib
import pandas as pd
from typing import Dict, Any

MODEL_PATH = "ml-service/models/wait_time_model.pkl"
LOADED_MODEL_DATA = None

def get_loaded_model():
    global LOADED_MODEL_DATA
    if LOADED_MODEL_DATA is None and os.path.exists(MODEL_PATH):
        try:
            LOADED_MODEL_DATA = joblib.load(MODEL_PATH)
        except Exception:
            LOADED_MODEL_DATA = None
    return LOADED_MODEL_DATA

def predict_wait(features: Dict[str, Any], centre_history_count: int = 0) -> Dict[str, Any]:
    farmers_ahead = float(features.get("farmers_ahead", 0))
    avg_proc_time = float(features.get("average_processing_time", 15.0))
    active_counters = max(1, int(features.get("active_counters", 1)))

    # Rule-based estimate
    rule_estimate = (farmers_ahead * avg_proc_time) / active_counters

    # Model estimate
    model_data = get_loaded_model()
    model_estimate = rule_estimate

    if model_data and "model" in model_data and "feature_cols" in model_data:
        try:
            model = model_data["model"]
            cols = model_data["feature_cols"]
            row_dict = {}
            for col in cols:
                row_dict[col] = [features.get(col, 0)]
            df = pd.DataFrame(row_dict)
            model_estimate = float(model.predict(df)[0])
        except Exception:
            model_estimate = rule_estimate

    # Weighted blending based on centre history volume
    if centre_history_count <= 0:
        blend_weight_model = 0.0
    else:
        # Ramp weight up to 0.9 based on historical volume
        blend_weight_model = min(0.9, centre_history_count / 50.0)

    raw_blended_wait = (blend_weight_model * model_estimate) + ((1.0 - blend_weight_model) * rule_estimate)

    # Clamp output to sane range [2.0, 300.0] minutes
    clamped_wait = max(2.0, min(300.0, raw_blended_wait))

    # Calculate confidence score
    confidence_score = round(min(0.95, max(0.50, 0.50 + (0.01 * min(centre_history_count, 45)))), 2)

    return {
        "predicted_wait_minutes": round(clamped_wait, 1),
        "rule_estimate": round(rule_estimate, 1),
        "model_estimate": round(model_estimate, 1),
        "blend_weight_model": round(blend_weight_model, 2),
        "confidence_score": confidence_score
    }
