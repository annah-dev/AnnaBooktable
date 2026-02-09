const CUISINES = ['All', 'American', 'Japanese', 'Italian', 'French', 'Mexican', 'Chinese', 'Thai'];

interface FilterSidebarProps {
  selectedCuisine: string;
  onCuisineChange: (cuisine: string) => void;
}

export default function FilterSidebar({ selectedCuisine, onCuisineChange }: FilterSidebarProps) {
  return (
    <aside className="w-60 p-7 pr-6 border-r border-border bg-bg-secondary sticky top-[65px] h-[calc(100vh-65px)] overflow-y-auto shrink-0">
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
            className="font-sans text-[13px] px-3 py-1.5 rounded-lg border border-border bg-transparent text-text-secondary hover:border-accent-glow hover:text-accent transition-all duration-200 cursor-pointer"
          >
            {'$'.repeat(p)}
          </button>
        ))}
      </div>

      <div className="font-sans text-[11px] font-semibold text-text-tertiary uppercase tracking-[1.5px] mt-8 mb-4">
        Rating
      </div>
      <div className="flex items-center gap-1.5">
        {[1, 2, 3, 4, 5].map(i => (
          <span key={i} className={`text-lg cursor-pointer ${i <= 4 ? 'text-accent' : 'text-bg-hover'}`}>★</span>
        ))}
        <span className="font-sans text-xs text-text-secondary ml-1">& up</span>
      </div>
    </aside>
  );
}
