from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from contextlib import asynccontextmanager
import time
import asyncio
import random
import hashlib
from typing import List, Optional
from datetime import datetime

from database import get_db, init_db
from models import Task, TaskCreate, TaskUpdate, TaskResponse

# Prometheus metrics
REQUEST_COUNT = Counter('api_requests_total', 'Total API requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('api_request_duration_seconds', 'API request duration', ['method', 'endpoint'])
ACTIVE_REQUESTS = Gauge('api_active_requests', 'Active API requests')
DB_OPERATIONS = Counter('db_operations_total', 'Total database operations', ['operation'])
CPU_INTENSIVE_TASKS = Counter('cpu_intensive_tasks_total', 'Total CPU intensive tasks')

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("🚀 API başlatılıyor...")
    await init_db()
    print("✅ Database hazır")
    yield
    # Shutdown
    print("👋 API kapatılıyor...")

# FastAPI app
app = FastAPI(
    title="Kubernetes Test Lab API",
    description="Load testing ve auto-scaling için test API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Request tracking middleware
@app.middleware("http")
async def track_requests(request, call_next):
    ACTIVE_REQUESTS.inc()
    start_time = time.time()
    
    response = await call_next(request)
    
    duration = time.time() - start_time
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    ACTIVE_REQUESTS.dec()
    
    return response

# Health check
@app.get("/health")
async def health_check():
    """Sağlık kontrolü endpoint'i"""
    return {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "service": "api"
    }

# Metrics endpoint
@app.get("/metrics")
async def get_metrics():
    """Prometheus metrics endpoint'i"""
    return generate_latest()

# Root endpoint
@app.get("/")
async def root():
    """Ana endpoint"""
    return {
        "message": "Kubernetes Test Lab API",
        "docs": "/docs",
        "health": "/health",
        "metrics": "/metrics"
    }

# Task CRUD endpoints
@app.post("/tasks", response_model=TaskResponse)
async def create_task(task: TaskCreate, db: AsyncSession = Depends(get_db)):
    """Yeni task oluştur"""
    DB_OPERATIONS.labels(operation="create").inc()
    
    db_task = Task(**task.dict())
    db.add(db_task)
    await db.commit()
    await db.refresh(db_task)
    
    return db_task

@app.get("/tasks", response_model=List[TaskResponse])
async def get_tasks(
    skip: int = 0,
    limit: int = 100,
    completed: Optional[bool] = None,
    db: AsyncSession = Depends(get_db)
):
    """Task listesini getir"""
    DB_OPERATIONS.labels(operation="list").inc()
    
    query = select(Task)
    
    if completed is not None:
        query = query.where(Task.completed == completed)
    
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    tasks = result.scalars().all()
    
    return tasks

@app.get("/tasks/{task_id}", response_model=TaskResponse)
async def get_task(task_id: int, db: AsyncSession = Depends(get_db)):
    """Tek bir task getir"""
    DB_OPERATIONS.labels(operation="get").inc()
    
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task bulunamadı")
    
    return task

@app.put("/tasks/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: int,
    task_update: TaskUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Task güncelle"""
    DB_OPERATIONS.labels(operation="update").inc()
    
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task bulunamadı")
    
    for field, value in task_update.dict(exclude_unset=True).items():
        setattr(task, field, value)
    
    task.updated_at = datetime.utcnow()
    await db.commit()
    await db.refresh(task)
    
    return task

@app.delete("/tasks/{task_id}")
async def delete_task(task_id: int, db: AsyncSession = Depends(get_db)):
    """Task sil"""
    DB_OPERATIONS.labels(operation="delete").inc()
    
    result = await db.execute(select(Task).where(Task.id == task_id))
    task = result.scalar_one_or_none()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task bulunamadı")
    
    await db.delete(task)
    await db.commit()
    
    return {"message": "Task silindi", "id": task_id}

# CPU intensive endpoints
@app.post("/cpu-intensive")
async def cpu_intensive_task(iterations: int = 1000000):
    """CPU yoğun işlem (test için)"""
    CPU_INTENSIVE_TASKS.inc()
    
    start_time = time.time()
    
    # CPU intensive operation
    result = 0
    for i in range(iterations):
        result += i ** 2
        if i % 100000 == 0:
            await asyncio.sleep(0)  # Event loop'a kontrol ver
    
    # Hash calculation (CPU intensive)
    data = str(result).encode()
    for _ in range(100):
        data = hashlib.sha256(data).digest()
    
    duration = time.time() - start_time
    
    return {
        "iterations": iterations,
        "result": result,
        "hash": data.hex(),
        "duration_seconds": duration
    }

@app.post("/memory-intensive")
async def memory_intensive_task(size_mb: int = 10):
    """Memory yoğun işlem (test için)"""
    if size_mb > 100:
        raise HTTPException(status_code=400, detail="Size 100MB'dan büyük olamaz")
    
    # Allocate memory
    data = []
    for _ in range(size_mb):
        # 1MB string data
        chunk = "x" * (1024 * 1024)
        data.append(chunk)
    
    # Some processing
    total_size = sum(len(chunk) for chunk in data)
    
    # Cleanup
    data.clear()
    
    return {
        "allocated_mb": size_mb,
        "total_bytes": total_size
    }

@app.get("/stats")
async def get_stats(db: AsyncSession = Depends(get_db)):
    """İstatistikleri getir"""
    DB_OPERATIONS.labels(operation="stats").inc()
    
    # Task count
    total_result = await db.execute(select(func.count(Task.id)))
    total_tasks = total_result.scalar()
    
    # Completed count
    completed_result = await db.execute(
        select(func.count(Task.id)).where(Task.completed == True)
    )
    completed_tasks = completed_result.scalar()
    
    # Recent tasks
    recent_result = await db.execute(
        select(Task).order_by(Task.created_at.desc()).limit(5)
    )
    recent_tasks = recent_result.scalars().all()
    
    return {
        "total_tasks": total_tasks,
        "completed_tasks": completed_tasks,
        "pending_tasks": total_tasks - completed_tasks,
        "recent_tasks": [
            {"id": t.id, "title": t.title, "created_at": t.created_at}
            for t in recent_tasks
        ]
    }

@app.post("/simulate-delay")
async def simulate_delay(delay_seconds: float = 1.0):
    """Gecikme simülasyonu"""
    if delay_seconds > 10:
        raise HTTPException(status_code=400, detail="Delay 10 saniyeden fazla olamaz")
    
    await asyncio.sleep(delay_seconds)
    
    return {
        "message": "İşlem tamamlandı",
        "delay_seconds": delay_seconds
    }

@app.post("/random-error")
async def random_error(error_rate: float = 0.2):
    """Rastgele hata üret (chaos testing için)"""
    if random.random() < error_rate:
        error_codes = [400, 404, 500, 502, 503]
        status_code = random.choice(error_codes)
        raise HTTPException(
            status_code=status_code,
            detail=f"Simulated error: {status_code}"
        )
    
    return {"message": "İşlem başarılı", "error_rate": error_rate}