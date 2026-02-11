import { useState } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';

export default function Header() {
  const navigate = useNavigate();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="flex justify-between items-center px-4 md:px-8 py-4 border-b border-border bg-[#0C0A09ee] glass sticky top-0 z-50">
      <div className="flex items-center gap-3 cursor-pointer" onClick={() => navigate('/')}>
        <div className="flex flex-col leading-none">
          <span className="font-sans text-[12px] md:text-[18px] font-semibold text-accent uppercase tracking-[8px] mb-0.5">
            Anna's
          </span>
          <span className="font-serif text-[28px] md:text-[44px] font-black text-text-primary tracking-tight relative">
            Book<span className="text-accent">table</span>
            <span className="absolute bottom-[-2px] left-0 right-0 h-[2px] bg-gradient-to-r from-accent to-transparent" />
          </span>
        </div>
      </div>

      {/* Desktop nav */}
      <nav className="hidden md:flex gap-8 items-center">
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

      {/* Mobile: avatar + hamburger */}
      <div className="flex md:hidden items-center gap-3">
        <div className="w-[30px] h-[30px] rounded-full bg-bg-elevated flex items-center justify-center border border-accent-glow font-sans text-[12px] font-semibold text-accent">
          A
        </div>
        <button
          onClick={() => setMenuOpen(!menuOpen)}
          className="flex flex-col gap-[5px] p-2 bg-transparent border-none cursor-pointer"
          aria-label="Toggle menu"
        >
          <span className={`block w-5 h-[2px] bg-text-secondary transition-all duration-200 ${menuOpen ? 'rotate-45 translate-y-[7px]' : ''}`} />
          <span className={`block w-5 h-[2px] bg-text-secondary transition-all duration-200 ${menuOpen ? 'opacity-0' : ''}`} />
          <span className={`block w-5 h-[2px] bg-text-secondary transition-all duration-200 ${menuOpen ? '-rotate-45 -translate-y-[7px]' : ''}`} />
        </button>
      </div>

      {/* Mobile drawer */}
      {menuOpen && (
        <div className="absolute top-full left-0 right-0 bg-[#0C0A09] border-b border-border md:hidden z-50">
          <nav className="flex flex-col p-4 gap-1">
            <NavLink
              to="/"
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                `font-sans text-sm font-medium px-4 py-3 rounded-lg no-underline transition-colors ${
                  isActive ? 'text-accent bg-accent/10' : 'text-text-secondary hover:text-text-primary'
                }`
              }
            >
              Search
            </NavLink>
            <NavLink
              to="/reservations"
              onClick={() => setMenuOpen(false)}
              className={({ isActive }) =>
                `font-sans text-sm font-medium px-4 py-3 rounded-lg no-underline transition-colors ${
                  isActive ? 'text-accent bg-accent/10' : 'text-text-secondary hover:text-text-primary'
                }`
              }
            >
              My Reservations
            </NavLink>
          </nav>
        </div>
      )}
    </header>
  );
}
