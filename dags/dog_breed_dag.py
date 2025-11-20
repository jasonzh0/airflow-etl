"""
Airflow DAG to fetch a random dog breed from the Dog API
API Documentation: https://dogapi.dog/docs/api-v2
Stores breed data in external PostgreSQL database
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.providers.standard.operators.python import PythonOperator
from airflow.sdk import Asset
from airflow.utils.log.logging_mixin import LoggingMixin
import requests
import json
import random
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
import os

# Set up logging - use Airflow's task logger for better UI compatibility
# Note: In Airflow tasks, we'll get the logger from the context
logger = logging.getLogger(__name__)

# Database connection configuration
# In Kubernetes, this will connect to the dog-breeds-db service
DB_CONFIG = {
    'host': os.getenv('DOG_BREEDS_DB_HOST', 'dog-breeds-db.dog-breeds.svc.cluster.local'),
    'port': os.getenv('DOG_BREEDS_DB_PORT', '5432'),
    'database': os.getenv('DOG_BREEDS_DB_NAME', 'dog_breeds_db'),
    'user': os.getenv('DOG_BREEDS_DB_USER', 'airflow'),
    'password': os.getenv('DOG_BREEDS_DB_PASSWORD', 'airflow'),
}

def get_db_connection():
    """Create and return a database connection"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        logger.info(f"✅ Connected to database: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
        return conn
    except Exception as e:
        logger.error(f"❌ Failed to connect to database: {e}")
        raise

# Default arguments for the DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Define the DAG
dag = DAG(
    'dog_breed_fetcher',
    default_args=default_args,
    description='Fetch a random dog breed from the Dog API (dogapi.dog)',
    schedule=timedelta(hours=1),  # Run every hour (Airflow 3 uses 'schedule' instead of 'schedule_interval')
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=['dog', 'api', 'example'],
)

def fetch_random_dog_breed(**context):
    """
    Fetch a random dog breed from the Dog API and store it in the database
    API: https://dogapi.dog/docs/api-v2
    """
    # Get Airflow task logger for better log visibility
    task_logger = logging.getLogger("airflow.task")
    
    try:
        # Dog API endpoint for breeds
        api_url = "https://dogapi.dog/api/v2/breeds"
        
        logger.info(f"Fetching dog breeds from: {api_url}")
        
        # Make GET request to the API
        response = requests.get(api_url, timeout=10)
        response.raise_for_status()  # Raise an exception for bad status codes
        
        # Parse JSON response
        data = response.json()
        
        # The API returns a structure with 'data' containing breeds
        if isinstance(data, dict) and 'data' in data:
            breeds = data['data']
        elif isinstance(data, list):
            breeds = data
        else:
            breeds = [data]
        
        if breeds and len(breeds) > 0:
            # Pick a random breed from the list
            random_breed = random.choice(breeds)
            
            # Extract breed information (structure may vary)
            breed_info = {}
            
            # Handle different possible response structures
            if isinstance(random_breed, dict):
                if 'attributes' in random_breed:
                    attrs = random_breed['attributes']
                    breed_info = {
                        'breed_name': attrs.get('name', 'Unknown'),
                        'description': attrs.get('description', 'No description available'),
                        'life_min': attrs.get('life', {}).get('min', None) if isinstance(attrs.get('life'), dict) else None,
                        'life_max': attrs.get('life', {}).get('max', None) if isinstance(attrs.get('life'), dict) else None,
                    }
                else:
                    # Direct attributes
                    breed_info = {
                        'breed_name': random_breed.get('name', random_breed.get('breed', 'Unknown')),
                        'description': random_breed.get('description', 'No description available'),
                        'life_min': random_breed.get('life_min', None),
                        'life_max': random_breed.get('life_max', None),
                    }
            
            breed_name = breed_info.get('breed_name', 'Unknown')
            description = breed_info.get('description', 'No description available')
            life_min = breed_info.get('life_min')
            life_max = breed_info.get('life_max')
            
            # Format life expectancy string
            if life_min and life_max:
                life_expectancy = f"{life_min}-{life_max} years"
            else:
                life_expectancy = 'N/A'
            
            result = {
                'breed_name': breed_name,
                'description': description,
                'life_expectancy': life_expectancy,
                'life_min': life_min,
                'life_max': life_max,
                'full_data': random_breed
            }
            
            logger.info(f"🐶 Random Dog Breed: {breed_name}")
            logger.info(f"Description: {description}")
            if result['life_expectancy'] != 'N/A':
                logger.info(f"Life Expectancy: {result['life_expectancy']}")
            
            # Store in database
            logger.info("=" * 80)
            logger.info("STARTING DATABASE INSERT OPERATION")
            logger.info("=" * 80)
            try:
                logger.info(f"Attempting to connect to database...")
                logger.info(f"DB Config: host={DB_CONFIG['host']}, port={DB_CONFIG['port']}, db={DB_CONFIG['database']}, user={DB_CONFIG['user']}")
                
                conn = get_db_connection()
                cursor = conn.cursor()
                
                # Get DAG run context
                dag_run = context['dag_run']
                ti = context['ti']
                
                # Handle execution_date - use logical_date or current time if None
                execution_date = context.get('execution_date') or context.get('logical_date') or dag_run.logical_date or datetime.utcnow()
                if execution_date and isinstance(execution_date, str):
                    execution_date = datetime.fromisoformat(execution_date.replace('Z', '+00:00'))
                
                logger.info(f"Inserting breed: {breed_name} for DAG run: {dag_run.run_id}")
                logger.info(f"Execution date: {execution_date}")
                logger.info(f"DAG ID: {ti.dag_id}, Task ID: {ti.task_id}")
                
                insert_query = """
                    INSERT INTO dog_breeds (
                        breed_name, description, life_expectancy, life_min, life_max,
                        dag_id, dag_run_id, task_id, execution_date, full_data
                    ) VALUES (
                        %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                    )
                    ON CONFLICT (dag_run_id, breed_name) 
                    DO UPDATE SET
                        description = EXCLUDED.description,
                        life_expectancy = EXCLUDED.life_expectancy,
                        life_min = EXCLUDED.life_min,
                        life_max = EXCLUDED.life_max,
                        full_data = EXCLUDED.full_data,
                        updated_at = CURRENT_TIMESTAMP
                    RETURNING id;
                """
                
                logger.info(f"Executing INSERT query with values:")
                logger.info(f"  breed_name={breed_name}")
                logger.info(f"  dag_id={ti.dag_id}")
                logger.info(f"  dag_run_id={dag_run.run_id}")
                logger.info(f"  task_id={ti.task_id}")
                logger.info(f"  execution_date={execution_date}")
                
                cursor.execute(insert_query, (
                    breed_name,
                    description,
                    life_expectancy,
                    life_min,
                    life_max,
                    ti.dag_id,
                    dag_run.run_id,
                    ti.task_id,
                    execution_date,
                    json.dumps(random_breed)
                ))
                
                breed_id = cursor.fetchone()[0]
                conn.commit()
                
                logger.info("=" * 80)
                logger.info(f"✅ SUCCESSFULLY STORED BREED IN DATABASE!")
                logger.info(f"   Breed ID: {breed_id}")
                logger.info(f"   Database: {DB_CONFIG['host']}/{DB_CONFIG['database']}")
                logger.info("=" * 80)
                
                cursor.close()
                conn.close()
                
            except Exception as db_error:
                logger.error("=" * 80)
                logger.error(f"❌ FAILED TO STORE BREED IN DATABASE!")
                logger.error(f"   Error: {db_error}")
                logger.error("=" * 80)
                import traceback
                logger.error(traceback.format_exc())
                # Continue even if database write fails
            
            # Log the full breed data (can be viewed in Airflow UI)
            logger.debug(f"Full breed data:\n{json.dumps(random_breed, indent=2)}")
            
            # Update asset with breed data
            logger.info(f"💾 Asset will be stored: dog_breed://random_breed")
            logger.info(f"   Breed: {breed_name}")
            logger.info(f"   Life Expectancy: {result['life_expectancy']}")
            
            # Store result in XCom for downstream tasks if needed
            return result
        else:
            logger.warning("No breeds found in API response")
            logger.debug(f"Response data: {json.dumps(data, indent=2)}")
            return None
            
    except requests.exceptions.RequestException as e:
        logger.error(f"Error fetching dog breed: {e}")
        logger.error(f"Response status: {getattr(e.response, 'status_code', 'N/A')}")
        logger.error(f"Response text: {getattr(e.response, 'text', 'N/A')}")
        raise
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        import traceback
        logger.error(traceback.format_exc())
        raise

def print_breed_summary(**context):
    """
    Print a summary of the fetched breed
    This task demonstrates task dependencies and XCom usage
    """
    # Get the result from the previous task
    ti = context['ti']
    dag_run = context['dag_run']
    
    # Get the result from the previous task via XCom
    breed_data = ti.xcom_pull(task_ids='fetch_dog_breed', key='return_value')
    
    if breed_data:
        breed_name = breed_data.get('breed_name', 'Unknown')
        life_span = breed_data.get('life_expectancy', 'N/A')
        description = breed_data.get('description', 'No description available')
        
        # Print in a simple format that should definitely show in UI
        output_lines = [
            "",
            "=" * 70,
            "BREED SUMMARY - RANDOM DOG BREED",
            "=" * 70,
            f"Breed Name: {breed_name}",
            f"Life Span: {life_span}",
            f"Description: {description}",
            "=" * 70,
            "Successfully retrieved random dog breed information!",
            "=" * 70,
            ""
        ]
        
        # Log each line using logger
        for line in output_lines:
            if line.strip():  # Only log non-empty lines
                # Use ERROR level to ensure visibility (most visible in UI)
                logger.error(f"BREED_SUMMARY: {line}")
                # Also log as WARNING
                logger.warning(f"BREED_SUMMARY: {line}")
                # And INFO
                logger.info(f"BREED_SUMMARY: {line}")
        
        # Also store in XCom with a clear key for easy viewing in UI
        ti.xcom_push(key='breed_summary', value={
            'breed_name': breed_name,
            'life_span': life_span,
            'description': description,
            'message': f'Random dog breed: {breed_name}'
        })
    else:
        logger.error("=" * 60)
        logger.error("❌ ERROR: No breed data available from previous task")
        logger.error("=" * 60)

# Define the asset that will be produced
dog_breed_asset = Asset(
    uri=f"dog_breed://random_breed",
    extra={
        'description': 'Random dog breed fetched from Dog API',
        'source': 'https://dogapi.dog/api/v2/breeds',
    }
)

# Define tasks
fetch_task = PythonOperator(
    task_id='fetch_dog_breed',
    python_callable=fetch_random_dog_breed,
    outlets=[dog_breed_asset],  # This task produces the asset
    dag=dag,
)

summary_task = PythonOperator(
    task_id='print_summary',
    python_callable=print_breed_summary,
    dag=dag,
)

# Set task dependencies
fetch_task >> summary_task
