import { format } from 'date-fns';

interface TimeSlotPillProps {
  startTime: string;
  available?: boolean;
  selected?: boolean;
  onClick?: () => void;
}

export default function TimeSlotPill({ startTime, available = true, selected = false, onClick }: TimeSlotPillProps) {
  const timeStr = format(new Date(startTime), 'h:mm a');

  if (!available) {
    return (
      <span className="font-mono text-xs px-3.5 py-1.5 rounded-lg border border-bg-hover text-text-tertiary line-through opacity-50">
        {timeStr}
      </span>
    );
  }

  return (
    <button
      onClick={(e) => { e.stopPropagation(); onClick?.(); }}
      className={`font-mono text-xs px-3.5 py-1.5 rounded-lg border transition-all duration-200 cursor-pointer
        ${selected
          ? 'bg-accent text-bg-primary border-accent font-medium'
          : 'accent-glow border-accent-glow text-accent hover:bg-accent hover:text-bg-primary'
        }`}
    >
      {timeStr}
    </button>
  );
}
