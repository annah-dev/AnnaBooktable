interface StarRatingProps {
  rating: number;
  showNumber?: boolean;
}

export default function StarRating({ rating, showNumber = true }: StarRatingProps) {
  return (
    <span className="inline-flex items-center gap-1">
      {[1, 2, 3, 4, 5].map(i => (
        <span key={i} className={`text-[13px] ${i <= Math.round(rating) ? 'text-accent' : 'text-bg-hover'}`}>★</span>
      ))}
      {showNumber && (
        <span className="font-mono text-xs text-text-secondary ml-1">{rating.toFixed(1)}</span>
      )}
    </span>
  );
}
