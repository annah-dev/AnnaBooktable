import { useState } from 'react';
import { useUserReservations, useCancelReservation } from '../api/reservations.ts';
import StatusBadge from '../components/common/StatusBadge.tsx';
import { format } from 'date-fns';

const STATUS_BORDER_COLOR: Record<string, string> = {
  CONFIRMED: 'border-l-accent',
  COMPLETED: 'border-l-success',
  CANCELLED: 'border-l-danger',
  NO_SHOW: 'border-l-text-tertiary',
};

const CUISINE_EMOJI: Record<string, string> = {
  'American': '🍔', 'Japanese': '🍣', 'Italian': '🍝', 'French': '🇫🇷',
  'Mexican': '🌮', 'Chinese': '🥟', 'Thai': '🍜', 'Korean': '🥘',
  'Indian': '🍛', 'Vietnamese': '🍲', 'Seafood': '🦀', 'Steakhouse': '🥩',
  'Mediterranean': '🫒', 'Taiwanese': '🧋', 'BBQ': '🔥', 'Pizza': '🍕',
};

export default function ReservationsPage() {
  const { data: reservations } = useUserReservations();
  const cancelMutation = useCancelReservation();
  const [confirmingId, setConfirmingId] = useState<string | null>(null);

  const handleCancel = (reservationId: string) => {
    if (confirmingId === reservationId) {
      setConfirmingId(null);
      cancelMutation.mutate(reservationId, {
        onError: () => setConfirmingId(null),
      });
    } else {
      setConfirmingId(reservationId);
    }
  };

  return (
    <div className="max-w-[700px] mx-auto p-8">
      <h2 className="font-serif text-[32px] text-text-primary mb-2">My Reservations</h2>
      <p className="font-sans text-sm text-text-tertiary mb-8">Upcoming and past bookings</p>

      {cancelMutation.isError && (
        <div className="mb-4 px-4 py-3 rounded-xl border border-danger bg-[rgba(239,68,68,0.1)] font-sans text-sm text-danger">
          Failed to cancel reservation. Please try again.
        </div>
      )}

      {(!reservations || reservations.length === 0) ? (
        <div className="text-center py-16">
          <div className="text-5xl mb-4 opacity-30">📋</div>
          <h3 className="font-serif text-xl text-text-primary mb-2">No reservations yet</h3>
          <p className="font-sans text-sm text-text-tertiary">Search for a restaurant and book your first table!</p>
        </div>
      ) : (
        reservations.map((res, i) => {
          const isPast = res.status !== 'CONFIRMED';
          const emoji = CUISINE_EMOJI[res.cuisine ?? ''] ?? '🍽️';
          const borderColor = STATUS_BORDER_COLOR[res.status] ?? 'border-l-text-tertiary';
          const dateStr = format(new Date(res.dateTime), 'MMM d, yyyy');
          const timeStr = format(new Date(res.dateTime), 'h:mm a');
          const isCancelling = cancelMutation.isPending && cancelMutation.variables === res.reservationId;
          const isConfirming = confirmingId === res.reservationId;

          return (
            <div
              key={res.reservationId}
              className={`flex gap-5 px-6 py-5 rounded-[14px] bg-bg-secondary border border-border mb-3 border-l-[3px] ${borderColor} transition-all duration-200 animate-fade-slide-up ${isPast ? 'opacity-60' : ''}`}
              style={{ animationDelay: `${i * 0.08}s` }}
            >
              <div className="w-[52px] h-[52px] rounded-xl bg-bg-elevated flex items-center justify-center text-[26px] shrink-0">
                {emoji}
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-start">
                  <div>
                    <div className="font-serif text-[17px] text-text-primary">{res.restaurantName}</div>
                    <div className="font-sans text-[13px] text-text-secondary mt-0.5">
                      {dateStr} · {timeStr} · {res.partySize} guests
                    </div>
                  </div>
                  <StatusBadge status={res.status} />
                </div>
                <div className="flex justify-between items-center mt-2.5">
                  <span className="font-mono text-[13px] text-text-tertiary">#{res.confirmationCode}</span>
                  {res.status === 'CONFIRMED' && (
                    <div className="flex items-center gap-2">
                      {isConfirming && !isCancelling && (
                        <button
                          onClick={() => setConfirmingId(null)}
                          className="font-sans text-xs text-text-tertiary bg-transparent border-none cursor-pointer p-1 hover:text-text-secondary transition-colors"
                        >
                          Keep
                        </button>
                      )}
                      <button
                        onClick={(e) => { e.stopPropagation(); handleCancel(res.reservationId); }}
                        disabled={isCancelling}
                        className={`font-sans text-xs border-none cursor-pointer px-3 py-1.5 rounded-lg transition-all disabled:opacity-50 disabled:cursor-not-allowed ${
                          isConfirming
                            ? 'bg-danger text-white font-semibold'
                            : 'bg-transparent text-danger p-1 hover:underline'
                        }`}
                      >
                        {isCancelling ? 'Cancelling...' : isConfirming ? 'Confirm cancel' : 'Cancel'}
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>
          );
        })
      )}
    </div>
  );
}
