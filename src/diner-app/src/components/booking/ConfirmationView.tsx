import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

interface ConfirmationViewProps {
  confirmationCode: string;
  restaurantName: string;
  dateTime: string;
  partySize: number;
}

export default function ConfirmationView({ confirmationCode, restaurantName, dateTime, partySize }: ConfirmationViewProps) {
  const navigate = useNavigate();
  const [animate, setAnimate] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => setAnimate(true), 100);
    return () => clearTimeout(t);
  }, []);

  const dateStr = new Date(dateTime).toLocaleDateString('en-US', {
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  });
  const timeStr = new Date(dateTime).toLocaleTimeString('en-US', {
    hour: 'numeric', minute: '2-digit',
  });

  return (
    <div className="min-h-screen flex flex-col items-center justify-center p-8"
      style={{ background: 'radial-gradient(ellipse at 50% 40%, rgba(34,197,94,0.08) 0%, transparent 60%)' }}>
      <div className={`transition-all duration-600 ease-out ${animate ? 'opacity-100 scale-100' : 'opacity-0 scale-[0.8]'}`}
           style={{ transitionTimingFunction: 'cubic-bezier(0.16, 1, 0.3, 1)' }}>
        <svg width="80" height="80" viewBox="0 0 80 80" className="block mx-auto mb-6">
          <circle cx="40" cy="40" r="38" fill="none" stroke="var(--color-success)" strokeWidth="2"
            className={`transition-opacity duration-400 ${animate ? 'opacity-100' : 'opacity-0'}`}
            style={{ transitionDelay: '0.2s' }} />
          <path d="M24 40 L35 51 L56 30" fill="none" stroke="var(--color-success)" strokeWidth="3"
            strokeLinecap="round" strokeLinejoin="round"
            strokeDasharray="50" strokeDashoffset={animate ? 0 : 50}
            style={{ transition: 'stroke-dashoffset 0.6s ease 0.4s' }} />
        </svg>
      </div>
      <h2 className={`font-serif text-[32px] text-text-primary mb-2 transition-opacity duration-500 ${animate ? 'opacity-100' : 'opacity-0'}`}
          style={{ transitionDelay: '0.6s' }}>
        Reservation confirmed
      </h2>
      <p className={`font-sans text-sm text-text-tertiary mb-8 transition-opacity duration-500 ${animate ? 'opacity-100' : 'opacity-0'}`}
         style={{ transitionDelay: '0.7s' }}>
        We've sent a confirmation to your email
      </p>

      <div className={`bg-bg-secondary rounded-2xl p-6 md:p-8 w-full max-w-[380px] border border-border text-center transition-all duration-600 ${animate ? 'opacity-100 translate-y-0' : 'opacity-0 translate-y-5'}`}
           style={{ transitionDelay: '0.8s', transitionTimingFunction: 'ease' }}>
        <div className="font-sans text-[11px] font-semibold text-text-tertiary uppercase tracking-[2px] mb-3">
          Confirmation Code
        </div>
        <div className="font-mono text-[28px] md:text-[40px] font-medium text-accent tracking-[4px] md:tracking-[8px] mb-6">
          {confirmationCode}
        </div>
        <div className="w-full h-px bg-border mb-5" />
        {[
          { label: 'Restaurant', value: restaurantName },
          { label: 'Date', value: dateStr },
          { label: 'Time', value: timeStr },
          { label: 'Guests', value: String(partySize) },
          { label: 'Deposit', value: '$25.00' },
        ].map(item => (
          <div key={item.label} className="flex justify-between mb-2.5">
            <span className="font-sans text-[13px] text-text-tertiary">{item.label}</span>
            <span className="font-sans text-[13px] text-text-primary font-medium">{item.value}</span>
          </div>
        ))}
        <div className="flex gap-2.5 mt-6">
          <button
            onClick={() => navigate('/')}
            className="flex-1 py-3 rounded-[10px] border border-border bg-transparent text-text-secondary cursor-pointer font-sans text-[13px] font-medium hover:border-accent-glow transition-colors"
          >
            Back to Search
          </button>
          <button
            onClick={() => navigate('/reservations')}
            className="flex-1 py-3 rounded-[10px] border-none bg-accent text-bg-primary cursor-pointer font-sans text-[13px] font-semibold hover:brightness-110 transition-all"
          >
            My Reservations
          </button>
        </div>
      </div>
    </div>
  );
}
