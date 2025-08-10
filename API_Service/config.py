import os

DB_USER = os.getenv("POSTGRES_USER", "moath")
DB_PASSWORD = os.getenv("DB_PASSWORD", "moath123")
DB_HOST = os.getenv("DB_HOST", "postgres-service") 
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("POSTGRES_DB", "users_db")
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "secret123")

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"