import { useState } from 'react';
import { useSearchParams, useNavigate } from 'react-router-dom';
import FilterSidebar from '../components/search/FilterSidebar.tsx';
import RestaurantCard from '../components/search/RestaurantCard.tsx';
import { useSearch } from '../api/search.ts';

function getTomorrow() {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

export default function SearchResultsPage() {
  const [searchParams] = useSearchParams();
  const navigate = useNavigate();
  const [selectedCuisine, setSelectedCuisine] = useState('All');
  const [selectedPrice, setSelectedPrice] = useState<number | null>(null);
  const [selectedRating, setSelectedRating] = useState<number | null>(null);
  const [filterOpen, setFilterOpen] = useState(false);

  const city = searchParams.get('city') ?? 'Bellevue';
  const date = searchParams.get('date') ?? getTomorrow();
  const time = searchParams.get('time') ?? '19:00';
  const partySize = Number(searchParams.get('partySize') ?? '2');

  const { data, isLoading } = useSearch({
    city,
    date,
    time,
    partySize,
    cuisine: selectedCuisine === 'All' ? undefined : selectedCuisine,
  });

  const allResults = data?.results ?? [];
  const results = allResults.filter(r => {
    if (selectedPrice !== null && r.priceLevel !== selectedPrice) return false;
    if (selectedRating !== null && r.avgRating < selectedRating) return false;
    return true;
  });

  const dateStr = new Date(date + 'T00:00:00').toLocaleDateString('en-US', {
    weekday: 'short', month: 'short', day: 'numeric',
  });
  const timeStr = new Date(`2000-01-01T${time}`).toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit',
  });

  return (
    <div className="flex min-h-screen">
      <FilterSidebar
        selectedCuisine={selectedCuisine} onCuisineChange={setSelectedCuisine}
        selectedPrice={selectedPrice} onPriceChange={setSelectedPrice}
        selectedRating={selectedRating} onRatingChange={setSelectedRating}
        isOpen={filterOpen} onClose={() => setFilterOpen(false)}
      />

      <main className="flex-1 p-4 md:p-7 md:px-8">
        <div className="flex justify-between items-baseline mb-6 gap-3">
          <div className="min-w-0">
            <h2 className="font-serif text-[28px] text-text-primary mb-1">{city}</h2>
            <span className="font-sans text-[13px] text-text-tertiary">
              {results.length} restaurants · {dateStr} · {timeStr} · {partySize} guests
            </span>
          </div>
          <div className="flex items-center gap-3 shrink-0">
            <button
              onClick={() => setFilterOpen(true)}
              className="md:hidden flex items-center gap-1.5 px-3 py-2 rounded-lg border border-border bg-bg-secondary text-text-secondary cursor-pointer font-sans text-xs hover:border-accent-glow transition-colors"
            >
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round">
                <line x1="4" y1="6" x2="20" y2="6"/><line x1="4" y1="12" x2="16" y2="12"/><line x1="4" y1="18" x2="12" y2="18"/>
              </svg>
              Filters
            </button>
            <span className="font-sans text-[13px] text-text-secondary hidden sm:inline">Sort: Top Rated</span>
          </div>
        </div>

        {isLoading ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-5">
            {[1, 2, 3, 4].map(i => (
              <div key={i} className="rounded-[14px] overflow-hidden bg-bg-secondary border border-border">
                <div className="h-32 md:h-40 animate-shimmer" />
                <div className="p-4 md:p-5 space-y-3">
                  <div className="h-5 w-2/3 rounded animate-shimmer" />
                  <div className="h-4 w-1/2 rounded animate-shimmer" />
                  <div className="flex gap-2">
                    {[1, 2, 3].map(j => <div key={j} className="h-8 w-20 rounded-lg animate-shimmer" />)}
                  </div>
                </div>
              </div>
            ))}
          </div>
        ) : results.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-24 text-center">
            <div className="text-6xl mb-6 opacity-30">🍽️</div>
            <h3 className="font-serif text-2xl text-text-primary mb-2">No tables match your search</h3>
            <p className="font-sans text-sm text-text-tertiary">Try adjusting your filters or search for a different date.</p>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4 md:gap-5">
            {results.map((r, i) => (
              <RestaurantCard
                key={r.restaurantId}
                restaurant={r}
                index={i}
                onCardClick={() => navigate(`/restaurant/${r.restaurantId}`)}
                onTimeClick={(slotId) => {
                  const slot = r.availableSlots.find(s => s.slotId === slotId);
                  navigate(`/book/${slotId}`, { state: { restaurant: r, slot } });
                }}
              />
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
