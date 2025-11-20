"""
FastAPI server for Dog Breeds Dashboard
Provides REST API to query dog breed data from PostgreSQL
"""

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor
import os
import logging
from datetime import datetime
from pydantic import BaseModel, Field

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DOG_BREEDS_DB_HOST', 'dog-breeds-db.dog-breeds.svc.cluster.local'),
    'port': os.getenv('DOG_BREEDS_DB_PORT', '5432'),
    'database': os.getenv('DOG_BREEDS_DB_NAME', 'dog_breeds_db'),
    'user': os.getenv('DOG_BREEDS_DB_USER', 'airflow'),
    'password': os.getenv('DOG_BREEDS_DB_PASSWORD', 'airflow'),
}

# CORS configuration
ALLOWED_ORIGINS = os.getenv('ALLOWED_ORIGINS', '*').split(',')

# Create FastAPI app
app = FastAPI(
    title="Dog Breeds API",
    description="API for querying dog breed data fetched by Airflow",
    version="1.0.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for API responses
class DogBreed(BaseModel):
    id: str
    breed_name: str
    description: Optional[str] = None
    life_expectancy: Optional[str] = None
    life_span: Optional[str] = None  # Alias for compatibility
    dag_id: str
    dag_run_id: str
    run_id: Optional[str] = None  # Alias for compatibility
    task_id: str
    execution_date: datetime
    start_date: Optional[datetime] = None  # Alias for compatibility
    created_at: datetime
    state: Optional[str] = "success"  # Default for compatibility

    class Config:
        from_attributes = True

class BreedStats(BaseModel):
    total_breeds: int
    unique_breeds: int
    latest_execution: Optional[datetime] = None

class HealthCheck(BaseModel):
    status: str
    database: str
    timestamp: datetime

# Database connection helper
def get_db_connection():
    """Create and return a database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        return conn
    except Exception as e:
        logger.error(f"Failed to connect to database: {e}")
        raise HTTPException(status_code=503, detail="Database connection failed")

# API Routes

@app.get("/", response_model=dict)
async def root():
    """Root endpoint"""
    return {
        "message": "Dog Breeds API",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "breeds": "/api/breeds",
            "recent_breeds": "/api/breeds/recent",
            "stats": "/api/breeds/stats",
        }
    }

@app.get("/health", response_model=HealthCheck)
async def health_check():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("SELECT 1")
        cursor.close()
        conn.close()
        
        return HealthCheck(
            status="healthy",
            database="connected",
            timestamp=datetime.utcnow()
        )
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return HealthCheck(
            status="unhealthy",
            database="disconnected",
            timestamp=datetime.utcnow()
        )

@app.get("/api/breeds", response_model=List[DogBreed])
async def get_breeds(
    limit: int = Query(default=10, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    dag_id: Optional[str] = Query(default=None)
):
    """Get dog breeds with pagination"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        if dag_id:
            query = """
                SELECT 
                    id::text,
                    breed_name,
                    description,
                    life_expectancy,
                    life_expectancy as life_span,
                    dag_id,
                    dag_run_id,
                    dag_run_id as run_id,
                    task_id,
                    execution_date,
                    execution_date as start_date,
                    created_at,
                    'success' as state
                FROM dog_breeds
                WHERE dag_id = %s
                ORDER BY execution_date DESC, created_at DESC
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, (dag_id, limit, offset))
        else:
            query = """
                SELECT 
                    id::text,
                    breed_name,
                    description,
                    life_expectancy,
                    life_expectancy as life_span,
                    dag_id,
                    dag_run_id,
                    dag_run_id as run_id,
                    task_id,
                    execution_date,
                    execution_date as start_date,
                    created_at,
                    'success' as state
                FROM dog_breeds
                ORDER BY execution_date DESC, created_at DESC
                LIMIT %s OFFSET %s
            """
            cursor.execute(query, (limit, offset))
        
        breeds = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        # Return empty list if no breeds found (not an error)
        if not breeds:
            return []
        
        return [DogBreed(**breed) for breed in breeds]
        
    except Exception as e:
        logger.error(f"Error fetching breeds: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch breeds: {str(e)}")

@app.get("/api/breeds/recent", response_model=List[DogBreed])
async def get_recent_breeds(
    limit: int = Query(default=20, ge=1, le=100),
    dag_id: str = Query(default="dog_breed_fetcher")
):
    """Get recent dog breeds (compatible with old API)"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                id::text,
                breed_name,
                description,
                life_expectancy,
                life_expectancy as life_span,
                dag_id,
                dag_run_id,
                dag_run_id as run_id,
                task_id,
                execution_date,
                execution_date as start_date,
                created_at,
                'success' as state
            FROM dog_breeds
            WHERE dag_id = %s
            ORDER BY execution_date DESC, created_at DESC
            LIMIT %s
        """
        
        cursor.execute(query, (dag_id, limit))
        breeds = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        # Return empty list if no breeds found (not an error)
        if not breeds:
            logger.info(f"No breeds found for dag_id: {dag_id}")
            return []
        
        return [DogBreed(**breed) for breed in breeds]
        
    except Exception as e:
        logger.error(f"Error fetching recent breeds: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Failed to fetch recent breeds: {str(e)}")

@app.get("/api/breeds/stats", response_model=BreedStats)
async def get_breed_stats(
    dag_id: Optional[str] = Query(default=None)
):
    """Get statistics about dog breeds"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        if dag_id:
            query = """
                SELECT 
                    COUNT(*) as total_breeds,
                    COUNT(DISTINCT breed_name) as unique_breeds,
                    MAX(execution_date) as latest_execution
                FROM dog_breeds
                WHERE dag_id = %s
            """
            cursor.execute(query, (dag_id,))
        else:
            query = """
                SELECT 
                    COUNT(*) as total_breeds,
                    COUNT(DISTINCT breed_name) as unique_breeds,
                    MAX(execution_date) as latest_execution
                FROM dog_breeds
            """
            cursor.execute(query)
        stats = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        return BreedStats(**stats)
        
    except Exception as e:
        logger.error(f"Error fetching stats: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch stats: {str(e)}")

@app.get("/api/breeds/{breed_id}", response_model=DogBreed)
async def get_breed_by_id(breed_id: str):
    """Get a specific breed by ID"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                id::text,
                breed_name,
                description,
                life_expectancy,
                life_expectancy as life_span,
                dag_id,
                dag_run_id,
                dag_run_id as run_id,
                task_id,
                execution_date,
                execution_date as start_date,
                created_at,
                'success' as state
            FROM dog_breeds
            WHERE id = %s::uuid
        """
        
        cursor.execute(query, (breed_id,))
        breed = cursor.fetchone()
        
        cursor.close()
        conn.close()
        
        if not breed:
            raise HTTPException(status_code=404, detail="Breed not found")
        
        return DogBreed(**breed)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching breed: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to fetch breed: {str(e)}")

@app.get("/api/breeds/search/{breed_name}", response_model=List[DogBreed])
async def search_breeds(
    breed_name: str,
    limit: int = Query(default=10, ge=1, le=100)
):
    """Search breeds by name"""
    try:
        conn = get_db_connection()
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        query = """
            SELECT 
                id::text,
                breed_name,
                description,
                life_expectancy,
                life_expectancy as life_span,
                dag_id,
                dag_run_id,
                dag_run_id as run_id,
                task_id,
                execution_date,
                execution_date as start_date,
                created_at,
                'success' as state
            FROM dog_breeds
            WHERE breed_name ILIKE %s
            ORDER BY execution_date DESC, created_at DESC
            LIMIT %s
        """
        
        cursor.execute(query, (f"%{breed_name}%", limit))
        breeds = cursor.fetchall()
        
        cursor.close()
        conn.close()
        
        return [DogBreed(**breed) for breed in breeds]
        
    except Exception as e:
        logger.error(f"Error searching breeds: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to search breeds: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("API_PORT", "8000"))
    host = os.getenv("API_HOST", "0.0.0.0")
    
    logger.info(f"Starting Dog Breeds API on {host}:{port}")
    logger.info(f"Database: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    logger.info(f"CORS origins: {ALLOWED_ORIGINS}")
    
    uvicorn.run(app, host=host, port=port)

