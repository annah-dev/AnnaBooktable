import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

export default function GlassSearchBar() {
  const navigate = useNavigate();
  const [city, setCity] = useState('San Francisco');
  const [date, setDate] = useState('2026-02-10');
  const [time, setTime] = useState('19:00');
  const [guests, setGuests] = useState('2');

  const handleSearch = () => {
    const params = new URLSearchParams({ city, date, time, partySize: guests });
    navigate(`/search?${params.toString()}`);
  };

  const fields = [
    { label: 'City', value: city, onChange: setCity, type: 'text', width: 'w-[180px]' },
    { label: 'Date', value: date, onChange: setDate, type: 'date', width: 'w-[160px]' },
    { label: 'Time', value: time, onChange: setTime, type: 'time', width: 'w-[160px]' },
    { label: 'Guests', value: guests, onChange: setGuests, type: 'number', width: 'w-[90px]' },
  ];

  return (
    <div className="flex gap-px rounded-2xl overflow-hidden bg-border p-px shadow-accent-glow glass">
      {fields.map(field => (
        <div key={field.label} className={`bg-bg-secondary px-5 py-3.5 ${field.width}`}>
          <div className="font-sans text-[10px] font-semibold text-text-tertiary uppercase tracking-[1.5px] mb-1.5">
            {field.label}
          </div>
          <input
            type={field.type}
            value={field.value}
            onChange={e => field.onChange(e.target.value)}
            className="bg-transparent border-none outline-none w-full font-sans text-[15px] text-text-primary"
          />
        </div>
      ))}
      <button
        onClick={handleSearch}
        className="bg-gradient-to-br from-accent to-accent-warm border-none px-8 py-3.5 cursor-pointer font-sans text-[15px] font-semibold text-bg-primary flex items-center gap-2 transition-all duration-200 whitespace-nowrap hover:brightness-110 active:scale-[0.97]"
      >
        Find tables
        <span className="text-lg">→</span>
      </button>
    </div>
  );
}
