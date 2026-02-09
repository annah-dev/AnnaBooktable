import { useState, useEffect, useCallback } from 'react';

export function useCountdown(expiresAt: string | null) {
  const getRemaining = useCallback(() => {
    if (!expiresAt) return 0;
    return Math.max(0, Math.floor((new Date(expiresAt).getTime() - Date.now()) / 1000));
  }, [expiresAt]);

  const [seconds, setSeconds] = useState(getRemaining);

  useEffect(() => {
    setSeconds(getRemaining());
    const interval = setInterval(() => {
      const remaining = getRemaining();
      setSeconds(remaining);
      if (remaining <= 0) clearInterval(interval);
    }, 1000);
    return () => clearInterval(interval);
  }, [getRemaining]);

  return {
    seconds,
    minutes: Math.floor(seconds / 60),
    secs: seconds % 60,
    isExpired: seconds <= 0,
    isUrgent: seconds > 0 && seconds < 60,
    progress: expiresAt ? seconds / 300 : 0,
  };
}
