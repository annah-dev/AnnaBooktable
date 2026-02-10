import { useState, useEffect } from 'react';
import { useParams, useLocation, useNavigate } from 'react-router-dom';
import CountdownTimer from '../components/booking/CountdownTimer.tsx';
import ConfirmationView from '../components/booking/ConfirmationView.tsx';
import { useAcquireHold, useReleaseHold } from '../api/inventory.ts';
import { useCreateReservation, USER_ID } from '../api/reservations.ts';
import { useCountdown } from '../hooks/useCountdown.ts';
import { format } from 'date-fns';

type Step = 'acquiring' | 'hold' | 'payment' | 'confirming' | 'confirmed' | 'error';

export default function BookingPage() {
  const { slotId } = useParams<{ slotId: string }>();
  const location = useLocation();
  const navigate = useNavigate();
  const state = location.state as { restaurant?: { name: string; restaurantId?: string }; slot?: { startTime: string; tableGroupName?: string; capacity?: number } } | null;

  const restaurantName = state?.restaurant?.name ?? 'Restaurant';
  const slotTime = state?.slot?.startTime ?? '';
  const tableInfo = state?.slot?.tableGroupName ?? 'Table';
  const capacity = state?.slot?.capacity ?? 2;

  const [step, setStep] = useState<Step>('acquiring');
  const [holdToken, setHoldToken] = useState<string | null>(null);
  const [expiresAt, setExpiresAt] = useState<string | null>(null);
  const [specialRequests, setSpecialRequests] = useState('');
  const [confirmationData, setConfirmationData] = useState<{ code: string; restaurantName: string; dateTime: string; partySize: number } | null>(null);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const acquireHold = useAcquireHold();
  const releaseHold = useReleaseHold();
  const createReservation = useCreateReservation();
  const countdown = useCountdown(expiresAt);

  // Redirect if no navigation state (direct URL or stale history)
  useEffect(() => {
    if (!state?.restaurant || !state?.slot) {
      navigate('/', { replace: true });
    }
  }, [state, navigate]);

  // Acquire hold on mount using mutateAsync + cleanup cancellation.
  // This is StrictMode-safe: mount 1's cleanup sets cancelled=true,
  // so only mount 2's promise result updates state.
  useEffect(() => {
    if (!slotId) return;
    let cancelled = false;

    acquireHold.mutateAsync({ slotId, userId: USER_ID })
      .then((data) => {
        if (cancelled) return;
        setHoldToken(data.holdToken);
        setExpiresAt(data.expiresAt);
        setStep('hold');
      })
      .catch((err: any) => {
        if (cancelled) return;
        const msg = err?.response?.data?.error ?? 'Failed to acquire hold. The slot may already be taken.';
        setErrorMessage(msg);
        setStep('error');
      });

    return () => { cancelled = true; };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [slotId]);

  // When countdown expires, show error (real-time check avoids stale-state issues)
  useEffect(() => {
    if (!expiresAt || step === 'confirmed' || step === 'confirming' || step === 'error') return;
    if (new Date(expiresAt).getTime() <= Date.now()) {
      setErrorMessage('Your hold has expired. Please try again.');
      setStep('error');
    }
  }, [countdown.seconds, expiresAt, step]);

  const handleRelease = () => {
    if (slotId) releaseHold.mutate(slotId);
    navigate(-1);
  };

  const handleConfirm = () => {
    if (!slotId) return;
    setStep('confirming');
    createReservation.mutateAsync({
      slotId,
      userId: USER_ID,
      holdToken: holdToken ?? undefined,
      partySize: capacity,
      specialRequests: specialRequests || undefined,
      paymentToken: 'tok_demo_visa',
      idempotencyKey: crypto.randomUUID(),
    })
      .then((data) => {
        setConfirmationData({
          code: data.confirmationCode,
          restaurantName: data.restaurantName || restaurantName,
          dateTime: data.dateTime || slotTime,
          partySize: data.partySize,
        });
        setStep('confirmed');
        // Replace history so browser back doesn't return to stale booking page
        window.history.replaceState(null, '', window.location.pathname);
      })
      .catch((err: any) => {
        const msg = err?.response?.data?.error ?? 'Booking failed. Please try again.';
        setErrorMessage(msg);
        setStep('error');
      });
  };

  if (step === 'confirmed' && confirmationData) {
    return (
      <ConfirmationView
        confirmationCode={confirmationData.code}
        restaurantName={confirmationData.restaurantName}
        dateTime={confirmationData.dateTime}
        partySize={confirmationData.partySize}
      />
    );
  }

  if (step === 'acquiring') {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-text-tertiary font-sans">Acquiring hold...</div>
      </div>
    );
  }

  if (step === 'error') {
    return (
      <div className="min-h-screen flex flex-col items-center justify-center p-8">
        <div className="text-4xl mb-4">⚠️</div>
        <h2 className="font-serif text-2xl text-text-primary mb-2">Something went wrong</h2>
        <p className="font-sans text-sm text-text-tertiary mb-6">{errorMessage}</p>
        <button
          onClick={() => navigate(-1)}
          className="px-6 py-3 rounded-xl border border-border bg-bg-secondary text-text-primary cursor-pointer font-sans text-sm hover:border-accent-glow transition-colors"
        >
          Go back
        </button>
      </div>
    );
  }

  const timeStr = slotTime ? format(new Date(slotTime), 'h:mm a') : '--:--';

  return (
    <div
      className="min-h-screen flex flex-col items-center px-8 pt-16 pb-8"
      style={{ background: 'radial-gradient(ellipse at 50% 20%, rgba(245,158,11,0.15) 0%, transparent 50%)' }}
    >
      <CountdownTimer seconds={countdown.seconds} total={300} isUrgent={countdown.isUrgent} />

      <p className="font-sans text-sm text-text-tertiary mt-4 mb-1">Your table is held</p>
      <p className="font-sans text-xs text-text-tertiary mb-8 opacity-60">
        Layer 1: Redis SETNX hold — 5 minute protection
      </p>

      <div className="bg-bg-secondary rounded-2xl p-8 w-[420px] border border-border">
        {/* Restaurant info */}
        <div className="flex justify-between mb-5 pb-4 border-b border-border">
          <div>
            <div className="font-serif text-xl text-text-primary">{restaurantName}</div>
            <div className="font-sans text-[13px] text-text-secondary mt-1">
              {timeStr} · {capacity} guests · {tableInfo}
            </div>
          </div>
          <div className="font-mono text-[13px] text-accent px-3 py-1.5 accent-glow rounded-lg self-start">
            $25
          </div>
        </div>

        {/* Step: Hold - special requests */}
        {step === 'hold' && (
          <div className="animate-fade-slide-up">
            <div className="mb-4">
              <label className="font-sans text-xs text-text-tertiary block mb-1.5">Special Requests</label>
              <textarea
                placeholder="Allergies, celebrations, seating preferences..."
                rows={3}
                value={specialRequests}
                onChange={e => setSpecialRequests(e.target.value)}
                className="w-full px-3.5 py-3 rounded-[10px] border border-border bg-bg-elevated text-text-primary outline-none resize-none font-sans text-sm focus:border-accent-glow transition-colors"
              />
            </div>
            <button
              onClick={() => setStep('payment')}
              className="w-full py-3.5 rounded-xl border-none cursor-pointer bg-gradient-to-br from-accent to-accent-warm font-sans text-[15px] font-semibold text-bg-primary hover:brightness-110 active:scale-[0.97] transition-all"
            >
              Continue to Payment →
            </button>
          </div>
        )}

        {/* Step: Payment */}
        {step === 'payment' && (
          <div className="animate-fade-slide-up">
            <div className="mb-4">
              <label className="font-sans text-xs text-text-tertiary block mb-1.5">Card Number</label>
              <input
                placeholder="4242 4242 4242 4242"
                defaultValue="4242 4242 4242 4242"
                className="w-full px-3.5 py-3 rounded-[10px] border border-border bg-bg-elevated text-text-primary outline-none font-mono text-sm focus:border-accent-glow transition-colors"
              />
            </div>
            <div className="flex gap-3 mb-5">
              <div className="flex-1">
                <label className="font-sans text-xs text-text-tertiary block mb-1.5">Expiry</label>
                <input
                  placeholder="MM/YY"
                  defaultValue="12/28"
                  className="w-full px-3.5 py-3 rounded-[10px] border border-border bg-bg-elevated text-text-primary outline-none font-mono text-sm focus:border-accent-glow transition-colors"
                />
              </div>
              <div className="flex-1">
                <label className="font-sans text-xs text-text-tertiary block mb-1.5">CVC</label>
                <input
                  placeholder="123"
                  defaultValue="123"
                  className="w-full px-3.5 py-3 rounded-[10px] border border-border bg-bg-elevated text-text-primary outline-none font-mono text-sm focus:border-accent-glow transition-colors"
                />
              </div>
            </div>
            <div className="px-3.5 py-2.5 rounded-[10px] accent-glow font-sans text-xs text-accent mb-4 border border-accent-glow">
              Defense layers active: Redis Hold (L1) · DB Constraint (L2) · Idempotency Key (L3)
            </div>
            <button
              onClick={handleConfirm}
              disabled={createReservation.isPending}
              className="w-full py-3.5 rounded-xl border-none cursor-pointer bg-gradient-to-br from-accent to-accent-warm font-sans text-[15px] font-semibold text-bg-primary hover:brightness-110 active:scale-[0.97] transition-all"
            >
              Confirm Booking · $25 deposit
            </button>
            <p className="font-sans text-[11px] text-text-tertiary text-center mt-3">
              Secured with Stripe · PCI compliant · Idempotent
            </p>
          </div>
        )}

        {/* Step: Confirming */}
        {step === 'confirming' && (
          <div className="flex items-center justify-center py-8">
            <div className="text-text-tertiary font-sans text-sm">Processing your reservation...</div>
          </div>
        )}
      </div>

      <button
        onClick={handleRelease}
        className="bg-transparent border-none text-text-tertiary cursor-pointer font-sans text-[13px] mt-5 hover:text-text-secondary transition-colors"
      >
        Release table & go back
      </button>
    </div>
  );
}
