from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
import os
import asyncio
from sqlalchemy import text

# Database URL from environment
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@postgres-service:5432/testdb"
)

# Create async engine
engine = create_async_engine(
    DATABASE_URL,
    echo=True,  # SQL logging
    pool_size=20,
    max_overflow=40,
    pool_pre_ping=True,  # Connection health check
    pool_recycle=3600,  # Recycle connections after 1 hour
)

# Session factory
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Base class for models
Base = declarative_base()

# Dependency for FastAPI
async def get_db():
    """Database session dependency"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        finally:
            await session.close()

# Database initialization
async def init_db():
    """Initialize database and create tables"""
    max_retries = 30
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            # Test connection
            async with engine.begin() as conn:
                await conn.execute(text("SELECT 1"))
                print(f"✅ Database connection successful (attempt {attempt + 1})")
            
            # Create tables
            async with engine.begin() as conn:
                await conn.run_sync(Base.metadata.create_all)
                print("✅ Database tables created")
            
            return
            
        except Exception as e:
            print(f"❌ Database connection failed (attempt {attempt + 1}/{max_retries}): {e}")
            if attempt < max_retries - 1:
                print(f"⏳ Retrying in {retry_delay} seconds...")
                await asyncio.sleep(retry_delay)
            else:
                raise Exception("Failed to connect to database after maximum retries")

# Cleanup function
async def close_db():
    """Close database connections"""
    await engine.dispose()
    print("✅ Database connections closed")