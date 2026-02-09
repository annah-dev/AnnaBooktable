const STATUS_STYLES: Record<string, string> = {
  CONFIRMED: 'bg-[rgba(245,158,11,0.15)] border-[rgba(245,158,11,0.3)] text-accent',
  COMPLETED: 'bg-[rgba(34,197,94,0.1)] border-[rgba(34,197,94,0.3)] text-success',
  CANCELLED: 'bg-[rgba(239,68,68,0.1)] border-[rgba(239,68,68,0.3)] text-danger',
  NO_SHOW:   'bg-[rgba(120,113,108,0.1)] border-[rgba(120,113,108,0.3)] text-text-tertiary',
  PENDING:   'bg-[rgba(245,158,11,0.1)] border-[rgba(245,158,11,0.2)] text-accent-warm',
};

interface StatusBadgeProps {
  status: string;
}

export default function StatusBadge({ status }: StatusBadgeProps) {
  const styles = STATUS_STYLES[status] ?? STATUS_STYLES.PENDING;
  return (
    <span className={`font-sans text-[11px] font-semibold px-3 py-1 rounded-full border uppercase tracking-wide ${styles}`}>
      {status.replace('_', ' ')}
    </span>
  );
}
