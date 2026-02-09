import { useQuery } from '@tanstack/react-query';
import api from './client.ts';
import type { ApiResponse } from './client.ts';

export interface SearchResult {
  restaurantId: string;
  name: string;
  cuisine: string | null;
  priceLevel: number | null;
  avgRating: number;
  distance: number | null;
  address: string | null;
  coverImageUrl: string | null;
  availableSlots: { slotId: string; startTime: string; endTime: string; capacity: number; tableGroupName: string | null }[];
}

export interface RestaurantDetail {
  restaurantId: string;
  name: string;
  cuisine: string | null;
  priceLevel: number | null;
  avgRating: number;
  totalReviews: number;
  address: string | null;
  city: string | null;
  state: string | null;
  zipCode: string | null;
  latitude: number | null;
  longitude: number | null;
  phone: string | null;
  website: string | null;
  description: string | null;
  coverImageUrl: string | null;
  operatingHours: string;
  amenities: string;
  tableGroups: { tableGroupId: string; name: string; description: string | null }[];
}

export interface SearchParams {
  query?: string;
  cuisine?: string;
  city?: string;
  date?: string;
  time?: string;
  partySize?: number;
  page?: number;
  pageSize?: number;
}

export function useSearch(params: SearchParams) {
  return useQuery({
    queryKey: ['search', params],
    queryFn: async () => {
      const { data } = await api.get<ApiResponse<{ results: SearchResult[]; totalCount: number }>>('/search', { params });
      return { results: data.data.results, totalCount: data.data.totalCount };
    },
  });
}

export function useRestaurantDetail(id: string) {
  return useQuery({
    queryKey: ['restaurant', id],
    queryFn: async () => {
      const { data } = await api.get<ApiResponse<RestaurantDetail>>(`/search/restaurants/${id}`);
      return data.data;
    },
    enabled: !!id,
  });
}
