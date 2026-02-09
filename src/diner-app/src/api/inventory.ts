import { useQuery, useMutation } from '@tanstack/react-query';
import api from './client.ts';
import type { ApiResponse } from './client.ts';

export interface AvailableSlot {
  slotId: string;
  startTime: string;
  endTime: string;
  tableNumber: string;
  tableGroupName: string | null;
  capacity: number;
}

export interface AvailabilityResponse {
  restaurantId: string;
  date: string;
  slots: AvailableSlot[];
}

export interface HoldResponse {
  holdToken: string;
  expiresAt: string;
  slotId: string;
}

export function useAvailability(restaurantId: string, date: string, partySize: number) {
  return useQuery({
    queryKey: ['availability', restaurantId, date, partySize],
    queryFn: async () => {
      const { data } = await api.get<ApiResponse<AvailabilityResponse>>('/inventory/availability', {
        params: { restaurantId, date, partySize },
      });
      return data.data;
    },
    enabled: !!restaurantId && !!date,
  });
}

export function useAcquireHold() {
  return useMutation({
    mutationFn: async ({ slotId, userId }: { slotId: string; userId: string }) => {
      const { data } = await api.post<ApiResponse<HoldResponse>>('/inventory/hold', { slotId, userId });
      return data.data;
    },
  });
}

export function useReleaseHold() {
  return useMutation({
    mutationFn: async (slotId: string) => {
      await api.delete(`/inventory/hold/${slotId}`);
    },
  });
}
