-- Dog Breeds Database Schema
-- This database stores dog breed information fetched by Airflow DAGs

-- Create database (run manually if needed)
-- CREATE DATABASE dog_breeds_db;

-- Connect to the database
-- \c dog_breeds_db;

-- Create extension for UUID support
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Dog breeds table
CREATE TABLE IF NOT EXISTS dog_breeds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    breed_name VARCHAR(255) NOT NULL,
    description TEXT,
    life_expectancy VARCHAR(100),
    life_min INTEGER,
    life_max INTEGER,
    
    -- Airflow metadata
    dag_id VARCHAR(255) NOT NULL,
    dag_run_id VARCHAR(255) NOT NULL,
    task_id VARCHAR(255) NOT NULL,
    execution_date TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- API response metadata
    full_data JSONB,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Add index for common queries
    CONSTRAINT unique_dag_run_breed UNIQUE(dag_run_id, breed_name)
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_dog_breeds_dag_id ON dog_breeds(dag_id);
CREATE INDEX IF NOT EXISTS idx_dog_breeds_execution_date ON dog_breeds(execution_date DESC);
CREATE INDEX IF NOT EXISTS idx_dog_breeds_breed_name ON dog_breeds(breed_name);
CREATE INDEX IF NOT EXISTS idx_dog_breeds_created_at ON dog_breeds(created_at DESC);

-- Create a view for easy querying
CREATE OR REPLACE VIEW recent_breeds AS
SELECT 
    id,
    breed_name,
    description,
    life_expectancy,
    dag_id,
    dag_run_id,
    execution_date,
    created_at
FROM dog_breeds
ORDER BY execution_date DESC, created_at DESC;

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER update_dog_breeds_updated_at
    BEFORE UPDATE ON dog_breeds
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Create a function to get recent breeds with pagination
CREATE OR REPLACE FUNCTION get_recent_breeds(
    p_limit INTEGER DEFAULT 10,
    p_offset INTEGER DEFAULT 0,
    p_dag_id VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    breed_name VARCHAR,
    description TEXT,
    life_expectancy VARCHAR,
    dag_id VARCHAR,
    dag_run_id VARCHAR,
    execution_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        db.id,
        db.breed_name,
        db.description,
        db.life_expectancy,
        db.dag_id,
        db.dag_run_id,
        db.execution_date,
        db.created_at
    FROM dog_breeds db
    WHERE p_dag_id IS NULL OR db.dag_id = p_dag_id
    ORDER BY db.execution_date DESC, db.created_at DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Grant permissions (adjust as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO airflow_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO airflow_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO airflow_user;

