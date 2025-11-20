// Use Dog Breeds API (FastAPI backend connected to PostgreSQL)
const DOG_BREEDS_API_URL = import.meta.env.VITE_DOG_BREEDS_API_URL || 'http://localhost:30800';

// Helper function to make API fetch requests
async function apiFetch(endpoint: string, options: RequestInit = {}): Promise<Response> {
  const url = `${DOG_BREEDS_API_URL}${endpoint}`;
  
  // Set headers
  const headers = new Headers(options.headers);
  headers.set('Content-Type', 'application/json');
  headers.set('Accept', 'application/json');
  
  // Debug: log request in development
  if (import.meta.env.DEV) {
    console.log('API Request:', url);
  }
  
  try {
    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      // Try to get error details from response
      let errorData = null;
      try {
        errorData = await response.json();
      } catch {
        errorData = { detail: response.statusText || `HTTP ${response.status}` };
      }
      
      const error = new Error(errorData.detail || `Request failed with status code ${response.status}`);
      (error as any).response = {
        status: response.status,
        statusText: response.statusText,
        data: errorData,
      };
      throw error;
    }

    return response;
  } catch (error: any) {
    // Handle network errors
    if (error.name === 'TypeError' && error.message.includes('fetch')) {
      throw new Error('Network error: Unable to connect to API. Make sure the API is running and port forwarding is active.');
    }
    throw error;
  }
}

export interface DogBreed {
  id: string;
  breed_name: string;
  description?: string;
  life_expectancy?: string;
  life_span?: string;
  dag_id: string;
  dag_run_id: string;
  run_id?: string;
  task_id: string;
  execution_date: string;
  start_date?: string;
  created_at: string;
  state?: string;
}

export interface BreedStats {
  total_breeds: number;
  unique_breeds: number;
  latest_execution?: string;
}

/**
 * Get breed summary from the database
 */
export async function getBreedSummary(dagId: string = 'dog_breed_fetcher'): Promise<any> {
  try {
    const response = await apiFetch(`/api/breeds/recent?limit=1&dag_id=${dagId}`);
    const data = await response.json();
    return data[0] || null;
  } catch (error) {
    console.error('Error fetching breed summary:', error);
    throw error;
  }
}

/**
 * Get all recent breed data from the database
 */
export async function getRecentBreeds(dagId: string = 'dog_breed_fetcher', limit: number = 10): Promise<DogBreed[]> {
  try {
    // URL encode the dag_id parameter to handle special characters
    const encodedDagId = encodeURIComponent(dagId);
    const response = await apiFetch(`/api/breeds/recent?limit=${limit}&dag_id=${encodedDagId}`);
    
    if (!response.ok) {
      const errorData = await response.json().catch(() => ({ detail: 'Unknown error' }));
      throw new Error(errorData.detail || `Request failed with status ${response.status}`);
    }
    
    const data = await response.json();
    return Array.isArray(data) ? data : [];
  } catch (error: any) {
    console.error('Error fetching recent breeds:', error);
    // Provide more helpful error messages
    if (error.message) {
      throw new Error(`Failed to fetch breeds: ${error.message}`);
    }
    throw error;
  }
}

/**
 * Get breed statistics from the database
 */
export async function getBreedStats(dagId?: string): Promise<BreedStats> {
  try {
    const url = dagId ? `/api/breeds/stats?dag_id=${dagId}` : '/api/breeds/stats';
    const response = await apiFetch(url);
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching breed stats:', error);
    throw error;
  }
}

/**
 * Get a specific breed by ID
 */
export async function getBreedById(breedId: string): Promise<DogBreed> {
  try {
    const response = await apiFetch(`/api/breeds/${breedId}`);
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error fetching breed:', error);
    throw error;
  }
}

/**
 * Search breeds by name
 */
export async function searchBreeds(breedName: string, limit: number = 10): Promise<DogBreed[]> {
  try {
    const response = await apiFetch(`/api/breeds/search/${encodeURIComponent(breedName)}?limit=${limit}`);
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error searching breeds:', error);
    throw error;
        }
}

/**
 * Check API health
 */
export async function checkHealth(): Promise<any> {
  try {
    const response = await apiFetch('/health');
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Error checking health:', error);
    throw error;
  }
}

