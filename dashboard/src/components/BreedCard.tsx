import type { DogBreed } from '../types';

interface BreedCardProps {
  breed: DogBreed & { run_id?: string; start_date?: string; state?: string };
}

export function BreedCard({ breed }: BreedCardProps) {
  const lifeSpan = breed.life_span || breed.life_expectancy || 'N/A';

  return (
    <div className="bg-white dark:bg-gray-800 rounded-lg shadow-lg p-6 hover:shadow-xl transition-shadow duration-300">
      <div className="flex items-start justify-between mb-4">
        <div>
          <h3 className="text-2xl font-bold text-gray-900 dark:text-white mb-2">
            🐕 {breed.breed_name}
          </h3>
          {lifeSpan !== 'N/A' && (
            <p className="text-sm text-gray-600 dark:text-gray-400">
              ⏱️ Life Span: <span className="font-semibold">{lifeSpan}</span>
            </p>
          )}
        </div>
        {breed.state && (
          <span
            className={`px-3 py-1 rounded-full text-xs font-semibold ${
              breed.state === 'success'
                ? 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
                : 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200'
            }`}
          >
            {breed.state}
          </span>
        )}
      </div>

      <p className="text-gray-700 dark:text-gray-300 leading-relaxed mb-4">
        {breed.description}
      </p>

      {breed.start_date && (
        <div className="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
          <p className="text-xs text-gray-500 dark:text-gray-400">
            Fetched: {new Date(breed.start_date).toLocaleString()}
          </p>
        </div>
      )}
    </div>
  );
}

