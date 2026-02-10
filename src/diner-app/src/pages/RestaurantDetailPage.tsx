import { useState } from 'react';
import { useParams, useNavigate, useSearchParams } from 'react-router-dom';
import { useRestaurantDetail } from '../api/search.ts';
import { useAvailability } from '../api/inventory.ts';
import StarRating from '../components/common/StarRating.tsx';
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

export default function RestaurantDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [activeTab, setActiveTab] = useState('All Seating');
  const date = searchParams.get('date') ?? getTomorrow();
  const partySize = Number(searchParams.get('partySize')) || 2;

  const { data: restaurant } = useRestaurantDetail(id ?? '');
  const { data: availability } = useAvailability(id ?? '', date, partySize);

  if (!restaurant) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-text-tertiary font-sans">Loading...</div>
      </div>
    );
  }

  const emoji = CUISINE_EMOJI[restaurant.cuisine ?? ''] ?? '🍽️';
  const priceStr = restaurant.priceLevel ? '$'.repeat(restaurant.priceLevel) : '';
  const priceMuted = restaurant.priceLevel ? '$'.repeat(4 - restaurant.priceLevel) : '';

  const tabs = ['All Seating', ...(restaurant.tableGroups?.map(tg => tg.name) ?? [])];
  const slots = availability?.slots ?? [];
  const filteredSlots = activeTab === 'All Seating'
    ? slots
    : slots.filter(s => s.tableGroupName === activeTab);

  return (
    <div className="max-w-[900px] mx-auto px-8 pb-16">
      {/* Hero */}
      <div className="h-[300px] rounded-b-[20px] overflow-hidden bg-gradient-to-br from-bg-elevated via-bg-hover to-bg-elevated flex items-center justify-center text-[100px] relative">
        {emoji}
        <div className="absolute bottom-0 left-0 right-0 px-8 pb-6 pt-16" style={{ background: 'linear-gradient(transparent, #0C0A09)' }}>
          <h1 className="font-serif text-[40px] font-bold text-text-primary mb-2">{restaurant.name}</h1>
          <div className="flex gap-4 items-center">
            <span className="font-sans text-sm text-text-secondary">{restaurant.cuisine}</span>
            <span className="text-accent-glow">·</span>
            <span className="text-text-secondary text-[13px] tracking-wider">
              {priceStr}<span className="text-bg-hover">{priceMuted}</span>
            </span>
            <span className="text-accent-glow">·</span>
            <StarRating rating={restaurant.avgRating} />
          </div>
        </div>
      </div>

      <div className="grid grid-cols-[1fr_300px] gap-10 mt-8">
        {/* Left column */}
        <div>
          <p className="font-sans text-[15px] text-text-secondary leading-relaxed mb-8">
            {restaurant.description}
          </p>

          <h3 className="font-serif text-2xl text-text-primary mb-5">Choose your table</h3>

          {/* Tabs */}
          <div className="flex gap-0 border-b border-border mb-6">
            {tabs.map(tab => (
              <button
                key={tab}
                onClick={() => setActiveTab(tab)}
                className={`font-sans text-[13px] font-medium px-5 py-2.5 border-none cursor-pointer bg-transparent transition-all duration-200 -mb-px
                  ${activeTab === tab
                    ? 'text-accent border-b-2 border-accent'
                    : 'text-text-tertiary border-b-2 border-transparent hover:text-text-secondary'
                  }`}
              >
                {tab}
              </button>
            ))}
          </div>

          {/* Time grid */}
          <div className="grid grid-cols-3 gap-2.5">
            {filteredSlots.map(slot => (
              <div
                key={slot.slotId}
                onClick={() => navigate(`/book/${slot.slotId}`, {
                  state: { restaurant, slot },
                })}
                className="p-4 rounded-xl border border-border bg-bg-secondary cursor-pointer transition-all duration-200 text-center hover:border-accent hover:accent-glow"
              >
                <div className="font-mono text-base text-text-primary mb-1">
                  {format(new Date(slot.startTime), 'h:mm a')}
                </div>
                <div className="font-sans text-[11px] text-text-tertiary">
                  {slot.tableGroupName ?? 'Table'} · Seats {slot.capacity}
                </div>
              </div>
            ))}
          </div>

          {filteredSlots.length === 0 && (
            <div className="text-center py-12">
              <div className="text-4xl mb-3 opacity-30">🕐</div>
              <p className="font-sans text-sm text-text-tertiary">No available slots for this selection</p>
            </div>
          )}
        </div>

        {/* Right sidebar */}
        <div className="sticky top-[90px] self-start">
          <div className="bg-bg-secondary rounded-2xl p-6 border border-border">
            <div className="font-sans text-[11px] font-semibold text-text-tertiary uppercase tracking-[1.5px] mb-4">
              Details
            </div>
            {[
              { icon: '📍', label: restaurant.address ?? 'San Francisco' },
              { icon: '🕐', label: 'Tue–Sun, 5:30 PM – 10:00 PM' },
              { icon: '👥', label: `Party of ${partySize}` },
              { icon: '📞', label: restaurant.phone ?? '(415) 555-0100' },
            ].map((item, i) => (
              <div key={i} className="flex gap-2.5 mb-3 font-sans text-[13px] text-text-secondary">
                <span>{item.icon}</span><span>{item.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
