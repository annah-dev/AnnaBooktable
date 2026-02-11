const CUISINES = [
  'All', 'American', 'Japanese', 'Italian', 'Korean', 'Chinese', 'Indian',
  'Thai', 'Vietnamese', 'Mexican', 'French', 'Seafood', 'Steakhouse',
  'Mediterranean', 'Taiwanese', 'BBQ', 'Pizza',
];

interface FilterSidebarProps {
  selectedCuisine: string;
  onCuisineChange: (cuisine: string) => void;
  selectedPrice: number | null;
  onPriceChange: (price: number | null) => void;
  selectedRating: number | null;
  onRatingChange: (rating: number | null) => void;
  isOpen?: boolean;
  onClose?: () => void;
}

export default function FilterSidebar({ selectedCuisine, onCuisineChange, selectedPrice, onPriceChange, selectedRating, onRatingChange, isOpen, onClose }: FilterSidebarProps) {
  const content = (
    <>
      <div className="font-sans text-[11px] font-semibold text-text-tertiary uppercase tracking-[1.5px] mb-4">
        Cuisine
      </div>
      {CUISINES.map(c => (
        <div
          key={c}
          onClick={() => onCuisineChange(c)}
          className={`font-sans text-sm px-3 py-2 mb-0.5 rounded-lg cursor-pointer transition-all duration-200
            ${selectedCuisine === c ? 'text-accent accent-glow' : 'text-text-secondary hover:text-text-primary'}`}
        >
          {c}
        </div>
      ))}

      <div className="font-sans text-[11px] font-semibold text-text-tertiary uppercase tracking-[1.5px] mt-8 mb-4">
        Price
      </div>
      <div className="flex gap-1.5">
        {[1, 2, 3, 4].map(p => (
          <button
            key={p}
            onClick={() => onPriceChange(selectedPrice === p ? null : p)}
            className={`font-sans text-[13px] px-3 py-1.5 rounded-lg border transition-all duration-200 cursor-pointer
              ${selectedPrice === p ? 'border-accent-glow text-accent accent-glow bg-accent/10' : 'border-border bg-transparent text-text-secondary hover:border-accent-glow hover:text-accent'}`}
          >
            {'$'.repeat(p)}
          </button>
        ))}
      </div>

      <div className="font-sans text-[11px] font-semibold text-text-tertiary uppercase tracking-[1.5px] mt-8 mb-4">
        Rating
      </div>
      <div className="flex flex-col gap-1">
        {[4, 3, 2, 1].map(minRating => (
          <div
            key={minRating}
            onClick={() => onRatingChange(selectedRating === minRating ? null : minRating)}
            className={`flex items-center gap-1.5 px-2 py-1 rounded-lg cursor-pointer transition-all duration-200
              ${selectedRating === minRating ? 'bg-accent/10' : 'hover:bg-bg-hover'}`}
          >
            {[1, 2, 3, 4, 5].map(i => (
              <span key={i} className={`text-base ${i <= minRating ? 'text-accent' : 'text-bg-hover'}`}>★</span>
            ))}
            <span className={`font-sans text-xs ml-1 ${selectedRating === minRating ? 'text-accent' : 'text-text-secondary'}`}>& up</span>
          </div>
        ))}
      </div>
    </>
  );

  return (
    <>
      {/* Desktop sidebar */}
      <aside className="hidden md:block w-60 p-7 pr-6 border-r border-border bg-bg-secondary sticky top-[65px] h-[calc(100vh-65px)] overflow-y-auto shrink-0">
        {content}
      </aside>

      {/* Mobile drawer */}
      {isOpen && (
        <div className="fixed inset-0 z-50 md:hidden">
          <div className="absolute inset-0 bg-black/50" onClick={onClose} />
          <aside className="absolute top-0 left-0 bottom-0 w-72 bg-bg-secondary p-6 overflow-y-auto">
            <div className="flex justify-between items-center mb-6">
              <span className="font-sans text-sm font-semibold text-text-primary">Filters</span>
              <button onClick={onClose} className="bg-transparent border-none text-text-secondary cursor-pointer text-xl p-1">&#x2715;</button>
            </div>
            {content}
          </aside>
        </div>
      )}
    </>
  );
}
