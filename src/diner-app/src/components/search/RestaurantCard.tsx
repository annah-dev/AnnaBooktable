import type { SearchResult } from '../../api/search.ts';
import StarRating from '../common/StarRating.tsx';
import TimeSlotPill from './TimeSlotPill.tsx';

const CUISINE_EMOJI: Record<string, string> = {
  'American': '🍔', 'Japanese': '🍣', 'Italian': '🍝',
  'French': '🇫🇷', 'Mexican': '🌮', 'Chinese': '🐉', 'Thai': '🍜',
};

interface RestaurantCardProps {
  restaurant: SearchResult;
  index: number;
  onCardClick: () => void;
  onTimeClick: (slotId: string) => void;
}

export default function RestaurantCard({ restaurant, index, onCardClick, onTimeClick }: RestaurantCardProps) {
  const priceStr = restaurant.priceLevel ? '$'.repeat(restaurant.priceLevel) : '';
  const priceMuted = restaurant.priceLevel ? '$'.repeat(4 - restaurant.priceLevel) : '';
  const emoji = CUISINE_EMOJI[restaurant.cuisine ?? ''] ?? '🍽️';

  return (
    <div
      className="rounded-[14px] overflow-hidden cursor-pointer bg-bg-secondary border border-border transition-all duration-300 hover:-translate-y-[3px] hover:border-accent-glow animate-fade-slide-up"
      style={{ animationDelay: `${index * 0.08}s` }}
      onClick={onCardClick}
    >
      <div className="h-40 bg-gradient-to-br from-bg-elevated to-bg-hover flex items-center justify-center text-[56px] relative">
        {emoji}
        <div className="absolute top-3 right-3 bg-[#0C0A09cc] rounded-lg px-2.5 py-1 backdrop-blur-[10px]">
          <StarRating rating={restaurant.avgRating} />
        </div>
      </div>
      <div className="p-5">
        <div className="flex justify-between items-center mb-1">
          <span className="font-serif text-[19px] font-semibold text-text-primary">{restaurant.name}</span>
          <span className="text-text-secondary text-[13px] tracking-wider">
            {priceStr}<span className="text-bg-hover">{priceMuted}</span>
          </span>
        </div>
        <div className="font-sans text-[13px] text-text-secondary mb-3.5">
          {restaurant.cuisine} · {restaurant.address}
        </div>
        <div className="flex gap-2 flex-wrap">
          {restaurant.availableSlots.slice(0, 6).map(slot => (
            <TimeSlotPill
              key={slot.slotId}
              startTime={slot.startTime}
              onClick={() => { onTimeClick(slot.slotId); }}
            />
          ))}
          {restaurant.availableSlots.length > 6 && (
            <span className="font-sans text-[11px] text-text-tertiary py-1.5 px-1">
              +{restaurant.availableSlots.length - 6}
            </span>
          )}
        </div>
      </div>
    </div>
  );
}
