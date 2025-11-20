import { useState, useEffect } from 'react';
import { getRecentBreeds, getBreedSummary } from '../api';
import { BreedCard } from './BreedCard';
import type { DogBreed } from '../types';

export function BreedDashboard() {
  const [breeds, setBreeds] = useState<(DogBreed & { run_id?: string; start_date?: string; state?: string })[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const fetchBreeds = async () => {
    try {
      setError(null);
      const data = await getRecentBreeds('dog_breed_fetcher', 20);
      setBreeds(data);
    } catch (err: any) {
      setError(err.message || 'Failed to fetch dog breeds');
      console.error('Error fetching breeds:', err);
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchBreeds();
    // Refresh every 30 seconds
    const interval = setInterval(() => {
      setRefreshing(true);
      fetchBreeds();
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  const handleRefresh = () => {
    setRefreshing(true);
    fetchBreeds();
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
          <p className="text-gray-600 dark:text-gray-400">Loading dog breeds...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-center max-w-md">
          <div className="bg-red-100 dark:bg-red-900 border border-red-400 text-red-700 dark:text-red-200 px-4 py-3 rounded mb-4">
            <p className="font-bold">Error</p>
            <p>{error}</p>
          </div>
          <button
            onClick={handleRefresh}
            className="bg-blue-600 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900 py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="mb-8">
          <div className="flex items-center justify-between">
            <div>
              <h1 className="text-4xl font-bold text-gray-900 dark:text-white mb-2">
                🐶 Dog Breed Dashboard
              </h1>
              <p className="text-gray-600 dark:text-gray-400">
                Random dog breeds fetched from the Dog API via Airflow
              </p>
            </div>
            <button
              onClick={handleRefresh}
              disabled={refreshing}
              className="bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-semibold py-2 px-4 rounded-lg flex items-center gap-2 transition-colors"
            >
              {refreshing ? (
                <>
                  <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white"></div>
                  Refreshing...
                </>
              ) : (
                <>
                  <span>🔄</span>
                  Refresh
                </>
              )}
            </button>
          </div>
        </div>

        {/* Stats */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Total Breeds</p>
            <p className="text-3xl font-bold text-gray-900 dark:text-white">{breeds.length}</p>
          </div>
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Successful Fetches</p>
            <p className="text-3xl font-bold text-green-600 dark:text-green-400">
              {breeds.filter((b) => b.state === 'success').length}
            </p>
          </div>
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow p-6">
            <p className="text-sm text-gray-600 dark:text-gray-400 mb-1">Last Updated</p>
            <p className="text-sm font-semibold text-gray-900 dark:text-white">
              {breeds[0]?.start_date
                ? new Date(breeds[0].start_date).toLocaleString()
                : 'Never'}
            </p>
          </div>
        </div>

        {/* Breed Cards */}
        {breeds.length === 0 ? (
          <div className="text-center py-12">
            <p className="text-gray-600 dark:text-gray-400 text-lg">
              No dog breeds found. Make sure the Airflow DAG has run successfully.
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {breeds.map((breed, index) => (
              <BreedCard key={breed.run_id || index} breed={breed} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

