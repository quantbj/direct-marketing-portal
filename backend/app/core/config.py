from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+psycopg://app:app@localhost:5432/app"
    STORAGE_ROOT: str = "storage"
    ESIGN_PROVIDER: str = "stub"
    ESIGN_WEBHOOK_SECRET: str = ""
    ESIGN_SKIP_WEBHOOK_SIGNATURE: bool = False

    model_config = SettingsConfigDict(env_file=".env")


settings = Settings()
