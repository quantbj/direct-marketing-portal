from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+psycopg://app:app@localhost:5432/app"
    STORAGE_ROOT: str = "backend/storage"

    model_config = SettingsConfigDict(env_file=".env")


settings = Settings()
