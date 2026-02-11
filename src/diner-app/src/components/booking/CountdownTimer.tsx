interface CountdownTimerProps {
  seconds: number;
  total: number;
  isUrgent: boolean;
}

export default function CountdownTimer({ seconds, total, isUrgent }: CountdownTimerProps) {
  const radius = 80;
  const circumference = 2 * Math.PI * radius;
  const progress = seconds / total;
  const minutes = Math.floor(seconds / 60);
  const secs = seconds % 60;

  const strokeColor = isUrgent ? 'var(--color-danger)' : 'var(--color-accent)';
  const glowColor = isUrgent ? 'rgba(239,68,68,0.25)' : 'rgba(245,158,11,0.25)';

  return (
    <div className="relative w-[160px] h-[160px] md:w-[200px] md:h-[200px]">
      <svg viewBox="0 0 200 200" className="w-full h-full -rotate-90">
        <circle cx="100" cy="100" r={radius} fill="none" stroke="var(--color-bg-elevated)" strokeWidth="4" />
        <circle
          cx="100" cy="100" r={radius} fill="none"
          stroke={strokeColor}
          strokeWidth="4" strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - progress)}
          style={{
            transition: 'stroke-dashoffset 1s linear, stroke 0.5s ease',
            filter: `drop-shadow(0 0 8px ${glowColor})`,
          }}
        />
      </svg>
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 text-center">
        <div
          className={`font-mono text-4xl font-medium ${isUrgent ? 'text-danger animate-pulse-slow' : 'text-text-primary'}`}
        >
          {minutes}:{String(secs).padStart(2, '0')}
        </div>
        <div className="font-sans text-[11px] text-text-tertiary mt-0.5">remaining</div>
      </div>
    </div>
  );
}
