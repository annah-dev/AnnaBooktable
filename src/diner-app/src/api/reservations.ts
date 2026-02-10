import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import api from './client.ts';
import type { ApiResponse } from './client.ts';

export interface BookingRequest {
  slotId: string;
  userId: string;
  holdToken?: string;
  partySize: number;
  specialRequests?: string;
  paymentToken?: string;
  idempotencyKey?: string;
}

export interface BookingResponse {
  reservationId: string;
  confirmationCode: string;
  status: string;
  restaurantName: string;
  cuisine?: string;
  dateTime: string;
  partySize: number;
}

export const USER_ID = 'e0000000-0000-0000-0000-000000000001';

export function useCreateReservation() {
  return useMutation({
    mutationFn: async (request: BookingRequest) => {
      const idempotencyKey = request.idempotencyKey ?? crypto.randomUUID();
      const { data } = await api.post<ApiResponse<BookingResponse>>('/reservations', request, {
        headers: { 'Idempotency-Key': idempotencyKey },
      });
      return data.data;
    },
  });
}

export function useUserReservations(userId?: string) {
  const uid = userId ?? USER_ID;
  return useQuery({
    queryKey: ['reservations', uid],
    queryFn: async () => {
      const { data } = await api.get<ApiResponse<BookingResponse[]>>(`/reservations/user/${uid}`);
      return data.data;
    },
  });
}

export function useCancelReservation() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (reservationId: string) => {
      const { data } = await api.post<ApiResponse<unknown>>(`/reservations/${reservationId}/cancel`, {});
      if (!data.success) throw new Error(data.error ?? 'Cancel failed');
      return reservationId;
    },
    onSuccess: (_data, reservationId) => {
      queryClient.setQueriesData<BookingResponse[]>(
        { queryKey: ['reservations'] },
        (old) => old?.map(r => r.reservationId === reservationId ? { ...r, status: 'CANCELLED' } : r),
      );
      queryClient.invalidateQueries({ queryKey: ['reservations'] });
    },
  });
}
