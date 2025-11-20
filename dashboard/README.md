# Dog Breed Dashboard

A React + Vite + Tailwind CSS 4 dashboard to view dog breeds fetched from Airflow.

## Features

- View random dog breeds fetched by the Airflow DAG
- Real-time updates (auto-refreshes every 30 seconds)
- Beautiful, responsive design with Tailwind CSS 4
- Dark mode support
- Shows breed name, description, and life expectancy

## Setup

1. Install dependencies:
```bash
pnpm install
```

2. Configure Airflow API (optional - defaults are set):
```bash
cp .env.example .env
# Edit .env with your Airflow credentials if needed
```

3. Start the development server:
```bash
pnpm dev
```

4. Open http://localhost:5173 in your browser

## Environment Variables

- `VITE_AIRFLOW_API_URL` - Airflow API URL (default: http://localhost:8080/api/v2)
- `VITE_AIRFLOW_USERNAME` - Airflow username (default: admin)
- `VITE_AIRFLOW_PASSWORD` - Airflow password (default: admin)

## Building for Production

```bash
pnpm build
```

The built files will be in the `dist/` directory.

## Requirements

- Airflow must be running and accessible
- The `dog_breed_fetcher` DAG must have run at least once
- Port forwarding to Airflow API must be active (or use the correct API URL)
