export interface DogBreed {
  breed_name: string;
  description: string;
  life_span: string;
  life_expectancy?: string;
  full_data?: any;
}

export interface BreedSummary {
  breed_name: string;
  life_span: string;
  description: string;
  message: string;
}

