import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    def __init__(self, override_env: dict = None):
        env = override_env if override_env is not None else os.environ

        db_url = env.get("DATABASE_URL")
        if not db_url or not db_url.strip():
            raise ValueError("Configuration Error: DATABASE_URL environment variable is missing or empty.")

        # Fix postgres:// legacy URI scheme if present
        if db_url.startswith("postgres://"):
            db_url = db_url.replace("postgres://", "postgresql://", 1)

        self.DATABASE_URL: str = db_url
        self.JWT_SECRET: str = env.get("JWT_SECRET", "default_kissanflow_secret_key_change_me")
        self.ENVIRONMENT: str = env.get("ENVIRONMENT", "development")
        self.DEMO_MODE: bool = env.get("DEMO_MODE", "false").lower() in ("true", "1", "yes")
        self.FCM_SERVER_KEY: str = env.get("FCM_SERVER_KEY", "placeholder_fcm_key")
        self.SMS_API_KEY: str = env.get("SMS_API_KEY", "placeholder_sms_key")
        self.OPENWEATHERMAP_API_KEY: str = env.get("OPENWEATHERMAP_API_KEY", "")
        self.MAPBOX_API_KEY: str = env.get("MAPBOX_API_KEY", "")

def get_settings(override_env: dict = None) -> Settings:
    return Settings(override_env=override_env)
