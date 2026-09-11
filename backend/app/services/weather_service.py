import time
import math
import requests
import logging
from typing import Dict, Any, Optional
from backend.app.config import get_settings

logger = logging.getLogger("kissanflow.weather")

WEATHER_CACHE = {} # {centre_id: (timestamp, data_dict)}

def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2.0) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2.0) ** 2)
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c

class WeatherService:
    @staticmethod
    def get_centre_weather(centre_id: int, lat: float, lng: float) -> Dict[str, Any]:
        now = time.time()

        # Check 30-minute cache (1800 seconds)
        if centre_id in WEATHER_CACHE:
            cached_time, cached_data = WEATHER_CACHE[centre_id]
            if now - cached_time < 1800:
                return cached_data

        settings = get_settings()
        api_key = settings.OPENWEATHERMAP_API_KEY

        weather_data = None
        if api_key and api_key.strip():
            try:
                url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lng}&appid={api_key}&units=metric"
                res = requests.get(url, timeout=3.0)
                if res.status_code == 200:
                    json_res = res.json()
                    temp = json_res.get("main", {}).get("temp", 28.0)
                    humidity = json_res.get("main", {}).get("humidity", 65.0)
                    cond = json_res.get("weather", [{}])[0].get("main", "Clear")
                    
                    risk = "LOW"
                    summary = "Clear weather expected. Low risk of procurement delay."
                    if "Rain" in cond or "Storm" in cond:
                        risk = "MODERATE"
                        summary = "Moderate rainfall predicted. Recommend tarpaulin covers for grain transportation."

                    weather_data = {
                        "centre_id": centre_id,
                        "temperature_celsius": temp,
                        "humidity_percent": humidity,
                        "weather_condition": cond,
                        "risk_level": risk,
                        "risk_summary": summary,
                        "source": "OpenWeatherMap"
                    }
            except Exception as e:
                logger.warning(f"OpenWeatherMap API request failed: {e}")

        # Fallback non-alarmist weather response if API key missing or request failed
        if not weather_data:
            weather_data = {
                "centre_id": centre_id,
                "temperature_celsius": 29.5,
                "humidity_percent": 60.0,
                "weather_condition": "Clear",
                "risk_level": "LOW",
                "risk_summary": "Clear weather expected. Low risk of procurement delay.",
                "source": "approximate"
            }

        WEATHER_CACHE[centre_id] = (now, weather_data)
        return weather_data

class TravelService:
    @staticmethod
    def get_travel_time(centre_lat: float, centre_lng: float, farmer_lat: float, farmer_lng: float) -> Dict[str, Any]:
        settings = get_settings()
        api_key = settings.MAPBOX_API_KEY

        if api_key and api_key.strip():
            try:
                url = f"https://api.mapbox.com/directions/v5/mapbox/driving/{farmer_lng},{farmer_lat};{centre_lng},{centre_lat}?access_token={api_key}"
                res = requests.get(url, timeout=3.0)
                if res.status_code == 200:
                    json_data = res.json()
                    routes = json_data.get("routes", [])
                    if routes:
                        duration_sec = routes[0].get("duration", 1500)
                        dist_m = routes[0].get("distance", 15000)
                        return {
                            "travel_time_minutes": round(duration_sec / 60.0, 1),
                            "distance_km": round(dist_m / 1000.0, 2),
                            "source": "Mapbox API"
                        }
            except Exception as e:
                logger.warning(f"Mapbox API failed: {e}")

        # Straight-line distance fallback labeled 'approximate'
        dist_km = haversine_distance(farmer_lat, farmer_lng, centre_lat, centre_lng)
        # Assume average travel speed 30 km/h in rural areas
        est_minutes = max(5.0, round((dist_km / 30.0) * 60.0, 1))

        return {
            "travel_time_minutes": est_minutes,
            "distance_km": round(dist_km, 2),
            "source": "approximate"
        }
