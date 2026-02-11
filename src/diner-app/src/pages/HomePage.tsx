import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import GlassSearchBar from '../components/search/GlassSearchBar.tsx';
import StarRating from '../components/common/StarRating.tsx';
import { useSearch } from '../api/search.ts';
import { format, addDays } from 'date-fns';

function getTomorrow() {
  return addDays(new Date(), 1).toISOString().slice(0, 10);
}

const CUISINE_EMOJI: Record<string, string> = {
  'American': '🍔', 'Japanese': '🍣', 'Italian': '🍝', 'French': '🇫🇷',
  'Mexican': '🌮', 'Chinese': '🥟', 'Thai': '🍜', 'Korean': '🥘',
  'Indian': '🍛', 'Vietnamese': '🍲', 'Seafood': '🦀', 'Steakhouse': '🥩',
  'Mediterranean': '🫒', 'Taiwanese': '🧋', 'BBQ': '🔥', 'Pizza': '🍕',
};

export default function HomePage() {
  const navigate = useNavigate();
  const [loaded, setLoaded] = useState(false);
  const { data } = useSearch({ city: 'Bellevue', partySize: 2, date: getTomorrow() });
  const trending = data?.results?.slice(0, 4) ?? [];

  useEffect(() => {
    const t = setTimeout(() => setLoaded(true), 100);
    return () => clearTimeout(t);
  }, []);

  return (
    <div className="min-h-screen flex flex-col">
      {/* Hero */}
      <div
        className="flex-1 flex flex-col items-center justify-center px-8 pt-20 pb-10"
        style={{ background: 'radial-gradient(ellipse at 50% 30%, rgba(245,158,11,0.15) 0%, transparent 60%)' }}
      >
        <h1
          className="font-serif text-[64px] font-normal text-text-primary mb-3 text-center tracking-tight"
          style={{
            opacity: loaded ? 1 : 0, transform: loaded ? 'translateY(0)' : 'translateY(20px)',
            transition: 'all 0.8s cubic-bezier(0.16, 1, 0.3, 1)',
          }}
        >
          Your table awaits
        </h1>
        <p
          className="font-sans text-[17px] text-text-tertiary mb-12 text-center"
          style={{
            opacity: loaded ? 1 : 0, transform: loaded ? 'translateY(0)' : 'translateY(20px)',
            transition: 'all 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.15s',
          }}
        >
          Discover and reserve at Bellevue's finest restaurants
        </p>
        <div
          style={{
            opacity: loaded ? 1 : 0, transform: loaded ? 'translateY(0)' : 'translateY(20px)',
            transition: 'all 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.3s',
          }}
        >
          <GlassSearchBar />
        </div>
      </div>

      {/* Trending */}
      <div
        className="px-8 pb-16 max-w-[1100px] mx-auto w-full"
        style={{ opacity: loaded ? 1 : 0, transition: 'opacity 0.8s ease 0.6s' }}
      >
        <h2 className="font-serif text-[28px] text-text-primary mb-2">Trending tonight</h2>
        <p className="font-sans text-sm text-text-tertiary mb-7">Popular reservations in Bellevue</p>
        <div className="flex gap-5 overflow-x-auto pb-4">
          {trending.map((r, i) => {
            const emoji = CUISINE_EMOJI[r.cuisine ?? ''] ?? '🍽️';
            const priceStr = r.priceLevel ? '$'.repeat(r.priceLevel) : '';
            const priceMuted = r.priceLevel ? '$'.repeat(4 - r.priceLevel) : '';
            return (
              <div
                key={r.restaurantId}
                onClick={() => navigate(`/restaurant/${r.restaurantId}`)}
                className="min-w-[240px] rounded-[14px] overflow-hidden cursor-pointer bg-bg-secondary border border-border transition-all duration-300 shrink-0 hover:-translate-y-1 hover:shadow-[0_12px_30px_rgba(0,0,0,0.4)]"
                style={{
                  opacity: loaded ? 1 : 0, transform: loaded ? 'translateX(0)' : 'translateX(30px)',
                  transition: `all 0.5s ease ${0.7 + i * 0.1}s`,
                }}
              >
                <div className="h-[140px] bg-gradient-to-br from-bg-elevated to-bg-hover flex items-center justify-center text-5xl">
                  {emoji}
                </div>
                <div className="px-[18px] py-4">
                  <div className="font-serif text-[17px] font-semibold text-text-primary mb-1.5">{r.name}</div>
                  <div className="flex justify-between items-center mb-2.5">
                    <span className="font-sans text-xs text-text-secondary">{r.cuisine}</span>
                    <span className="text-text-secondary text-[13px] tracking-wider">
                      {priceStr}<span className="text-bg-hover">{priceMuted}</span>
                    </span>
                  </div>
                  <StarRating rating={r.avgRating} />
                  <div className="flex gap-1.5 mt-3 flex-wrap">
                    {r.availableSlots
                      .filter((s, i, arr) => arr.findIndex(x => new Date(x.startTime).getTime() === new Date(s.startTime).getTime()) === i)
                      .slice(0, 3).map(slot => (
                      <span key={slot.slotId} className="font-mono text-[11px] px-2.5 py-[5px] rounded-lg border border-accent-glow text-accent accent-glow">
                        {format(new Date(slot.startTime), 'h:mm a')}
                      </span>
                    ))}
                    {r.availableSlots.filter((s, i, arr) => arr.findIndex(x => new Date(x.startTime).getTime() === new Date(s.startTime).getTime()) === i).length > 3 && (
                      <span className="font-sans text-[11px] text-text-tertiary py-[5px] px-1">
                        +{r.availableSlots.filter((s, i, arr) => arr.findIndex(x => new Date(x.startTime).getTime() === new Date(s.startTime).getTime()) === i).length - 3}
                      </span>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}
