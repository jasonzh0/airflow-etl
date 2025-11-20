// Use relative path in development (proxied by Vite) or full URL from env
const AIRFLOW_API_URL = import.meta.env.VITE_AIRFLOW_API_URL || '/api/v2';

// Get credentials
const username = import.meta.env.VITE_AIRFLOW_USERNAME || 'admin';
const password = import.meta.env.VITE_AIRFLOW_PASSWORD || 'admin';

// Create Basic Auth header manually to ensure it works through proxy
const authHeader = `Basic ${btoa(`${username}:${password}`)}`;

// Helper function to make authenticated fetch requests
async function apiFetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
  const url = `${AIRFLOW_API_URL}${endpoint}`;
  
  // Merge headers properly - ensure Authorization is always set
  const headers = new Headers(options.headers);
  headers.set('Content-Type', 'application/json');
  headers.set('Authorization', authHeader);
  
  // Debug: verify auth header is set (remove in production)
  if (import.meta.env.DEV) {
    console.log('API Request:', url, 'Auth header set:', !!headers.get('Authorization'));
  }
  
  const response = await fetch(url, {
    ...options,
    headers,
  });

  if (!response.ok) {
    const error = new Error(`Request failed with status code ${response.status}`);
    (error as any).response = {
      status: response.status,
      statusText: response.statusText,
      data: await response.json().catch(() => null),
    };
    throw error;
  }

  return response;
}

export interface XComValue {
  value: any;
  timestamp: string;
}

export interface TaskInstance {
  dag_id: string;
  task_id: string;
  run_id: string;
  state: string;
}

/**
 * Get the latest DAG run for a specific DAG
 */
export async function getLatestDagRun(dagId: string): Promise<any> {
  try {
    const params = new URLSearchParams({
      limit: '1',
      order_by: '-start_date',
    });
    const response = await apiFetch(`/dags/${dagId}/dagRuns?${params}`);
    const data = await response.json();
    return data.dag_runs?.[0] || null;
  } catch (error) {
    console.error('Error fetching DAG run:', error);
    throw error;
  }
}

/**
 * Get XCom value from a task instance
 */
export async function getXComValue(
  dagId: string,
  runId: string,
  taskId: string,
  key: string = 'return_value'
): Promise<any> {
  try {
    const response = await apiFetch(
      `/dags/${dagId}/dagRuns/${runId}/taskInstances/${taskId}/xcomEntries/${key}`
    );
    const data = await response.json();
    return data.value;
  } catch (error) {
    console.error('Error fetching XCom value:', error);
    throw error;
  }
}

/**
 * Get breed summary from the print_summary task XCom
 */
export async function getBreedSummary(dagId: string = 'dog_breed_fetcher'): Promise<any> {
  try {
    const dagRun = await getLatestDagRun(dagId);
    if (!dagRun) {
      throw new Error('No DAG run found');
    }

    // Try to get breed_summary from print_summary task
    try {
      const breedSummary = await getXComValue(
        dagId,
        dagRun.dag_run_id,
        'print_summary',
        'breed_summary'
      );
      return breedSummary;
    } catch (e) {
      // Fallback: get return_value from fetch_dog_breed task
      const breedData = await getXComValue(
        dagId,
        dagRun.dag_run_id,
        'fetch_dog_breed',
        'return_value'
      );
      return breedData;
    }
  } catch (error) {
    console.error('Error fetching breed summary:', error);
    throw error;
  }
}

/**
 * Get all recent breed data from multiple DAG runs
 */
export async function getRecentBreeds(dagId: string = 'dog_breed_fetcher', limit: number = 10): Promise<any[]> {
  try {
    const params = new URLSearchParams({
      limit: limit.toString(),
      order_by: '-start_date',
    });
    const response = await apiFetch(`/dags/${dagId}/dagRuns?${params}`);
    const data = await response.json();

    const dagRuns = data.dag_runs || [];
    const breeds: any[] = [];

    for (const run of dagRuns) {
      try {
        // Try print_summary first
        const breedSummary = await getXComValue(
          dagId,
          run.dag_run_id,
          'print_summary',
          'breed_summary'
        );
        if (breedSummary) {
          breeds.push({
            ...breedSummary,
            run_id: run.dag_run_id,
            start_date: run.start_date,
            state: run.state,
          });
        }
      } catch (e) {
        // Try fetch_dog_breed as fallback
        try {
          const breedData = await getXComValue(
            dagId,
            run.dag_run_id,
            'fetch_dog_breed',
            'return_value'
          );
          if (breedData) {
            breeds.push({
              breed_name: breedData.breed_name,
              life_span: breedData.life_expectancy || breedData.life_span,
              description: breedData.description,
              run_id: run.dag_run_id,
              start_date: run.start_date,
              state: run.state,
            });
          }
        } catch (err) {
          // Skip this run if we can't get data
          console.warn(`Could not fetch breed data for run ${run.dag_run_id}`);
        }
      }
    }

    return breeds;
  } catch (error) {
    console.error('Error fetching recent breeds:', error);
    throw error;
  }
}

