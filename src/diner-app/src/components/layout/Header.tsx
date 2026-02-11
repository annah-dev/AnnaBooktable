import { NavLink, useNavigate } from 'react-router-dom';

export default function Header() {
  const navigate = useNavigate();

  return (
    <header className="flex justify-between items-center px-8 py-4 border-b border-border bg-[#0C0A09ee] glass sticky top-0 z-50">
      <div className="flex items-center gap-3 cursor-pointer" onClick={() => navigate('/')}>
        <div className="flex flex-col leading-none">
          <span className="font-sans text-[18px] font-semibold text-accent uppercase tracking-[8px] mb-0.5">
            Anna's
          </span>
          <span className="font-serif text-[44px] font-black text-text-primary tracking-tight relative">
            Book<span className="text-accent">table</span>
            <span className="absolute bottom-[-2px] left-0 right-0 h-[2px] bg-gradient-to-r from-accent to-transparent" />
          </span>
        </div>
      </div>
      <nav className="flex gap-8 items-center">
        <NavLink to="/" className={({ isActive }) =>
          `font-sans text-sm font-medium pb-1 border-b-2 transition-colors duration-200 no-underline ${
            isActive ? 'text-accent border-accent' : 'text-text-secondary border-transparent hover:text-text-primary'
          }`
        }>
          Search
        </NavLink>
        <NavLink to="/reservations" className={({ isActive }) =>
          `font-sans text-sm font-medium pb-1 border-b-2 transition-colors duration-200 no-underline ${
            isActive ? 'text-accent border-accent' : 'text-text-secondary border-transparent hover:text-text-primary'
          }`
        }>
          My Reservations
        </NavLink>
        <div className="w-[34px] h-[34px] rounded-full bg-bg-elevated flex items-center justify-center border border-accent-glow cursor-pointer font-sans text-[13px] font-semibold text-accent">
          A
        </div>
      </nav>
    </header>
  );
}
