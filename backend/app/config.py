import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Telegram 2.0 Messenger API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api/v1"
    
    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        "postgresql://postgres:postgres@localhost:54322/postgres"
    )
    
    # Security
    JWT_SECRET: str = os.getenv("JWT_SECRET", "super-secret-messenger-jwt-key-2026")
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    
    # Supabase connection fallback (optional)
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://kjsxbrbtpcizgaxypctv.supabase.co")
    SUPABASE_KEY: str = os.getenv("SUPABASE_KEY", "")
    
    # Storage
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "./uploads")
    
    class Config:
        case_sensitive = True
        env_file = ".env"

settings = Settings()
