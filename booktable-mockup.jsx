import { useState, useEffect, useRef } from "react";

const FONTS_URL = "https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700;900&family=DM+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap";

// Inject fonts
const fontLink = document.createElement("link");
fontLink.href = FONTS_URL;
fontLink.rel = "stylesheet";
document.head.appendChild(fontLink);

const theme = {
  bgPrimary: "#0C0A09",
  bgSecondary: "#1C1917",
  bgElevated: "#292524",
  bgHover: "#44403C",
  textPrimary: "#FAFAF9",
  textSecondary: "#A8A29E",
  textTertiary: "#78716C",
  accent: "#F59E0B",
  accentWarm: "#D97706",
  accentGlow: "rgba(245, 158, 11, 0.15)",
  success: "#22C55E",
  danger: "#EF4444",
  border: "#292524",
  borderAccent: "rgba(245, 158, 11, 0.3)",
};

const restaurants = [
  { id: 1, name: "The Sushi Bar", cuisine: "Japanese", price: 3, rating: 4.7, image: "🍣", address: "123 Mission St, SF", desc: "Omakase-driven sushi with seasonal fish flown in from Tsukiji. Intimate 24-seat counter dining.", times: ["6:00 PM", "6:30 PM", "7:00 PM", "7:30 PM", "8:00 PM", "8:30 PM"], tables: ["Bar 1", "Bar 2", "Table 3", "Patio 5"] },
  { id: 2, name: "Nopa", cuisine: "Californian", price: 3, rating: 4.5, image: "🥘", address: "560 Divisadero St, SF", desc: "Wood-fired organic cuisine in a converted bank building. Late-night menu until 1 AM.", times: ["7:00 PM", "7:30 PM", "8:30 PM", "9:00 PM"], tables: ["Main 1", "Main 4", "Window 2"] },
  { id: 3, name: "Tartine Manufactory", cuisine: "Bakery & Cafe", price: 2, rating: 4.6, image: "🥐", address: "595 Alabama St, SF", desc: "From the legendary Tartine bakery. All-day dining with house-milled grains and seasonal produce.", times: ["6:00 PM", "6:30 PM", "7:00 PM", "9:00 PM", "9:30 PM"], tables: ["Communal 1", "Table 2", "Patio 3"] },
  { id: 4, name: "Lazy Bear", cuisine: "Modern American", price: 4, rating: 4.9, image: "🐻", address: "3416 19th St, SF", desc: "Michelin-starred communal dining experience. Multi-course tasting menu changes weekly.", times: ["6:00 PM", "8:30 PM"], tables: ["Communal A", "Communal B"] },
  { id: 5, name: "La Taqueria", cuisine: "Mexican", price: 1, rating: 4.4, image: "🌮", address: "2889 Mission St, SF", desc: "Legendary Mission District taqueria. No rice in the burritos — just meat, beans, and perfection.", times: ["6:00 PM", "6:30 PM", "7:00 PM", "7:30 PM", "8:00 PM", "8:30 PM", "9:00 PM"], tables: ["Table 1", "Table 2", "Table 3", "Counter 1"] },
  { id: 6, name: "Atelier Crenn", cuisine: "French", price: 4, rating: 4.8, image: "🇫🇷", address: "3127 Fillmore St, SF", desc: "Three Michelin stars. Poetic culinaria — each dish tells a story from Chef Crenn's memoir.", times: ["7:00 PM", "9:00 PM"], tables: ["Table 1", "Table 4"] },
];

function StarRating({ rating }) {
  return (
    <span style={{ display: "inline-flex", alignItems: "center", gap: 4 }}>
      {[1,2,3,4,5].map(i => (
        <span key={i} style={{ color: i <= Math.round(rating) ? theme.accent : theme.bgHover, fontSize: 13 }}>★</span>
      ))}
      <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 12, color: theme.textSecondary, marginLeft: 4 }}>{rating}</span>
    </span>
  );
}

function PriceLevel({ level }) {
  return (
    <span style={{ color: theme.textSecondary, fontSize: 13, letterSpacing: 1 }}>
      {Array(level).fill("$").join("")}
      <span style={{ color: theme.bgHover }}>{Array(4-level).fill("$").join("")}</span>
    </span>
  );
}

function GrainOverlay() {
  return (
    <div style={{
      position: "fixed", top: 0, left: 0, right: 0, bottom: 0,
      backgroundImage: `url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)' opacity='0.03'/%3E%3C/svg%3E")`,
      pointerEvents: "none", zIndex: 1, opacity: 0.5,
    }} />
  );
}

function Header({ currentPage, onNavigate }) {
  return (
    <header style={{
      display: "flex", justifyContent: "space-between", alignItems: "center",
      padding: "16px 32px", borderBottom: `1px solid ${theme.border}`,
      background: `${theme.bgPrimary}ee`, backdropFilter: "blur(20px)",
      position: "sticky", top: 0, zIndex: 50,
    }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12, cursor: "pointer" }} onClick={() => onNavigate("home")}>
        <div style={{ display: "flex", flexDirection: "column", lineHeight: 1 }}>
          <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 9, fontWeight: 600, color: theme.accent, textTransform: "uppercase", letterSpacing: 4, marginBottom: 2 }}>Anna's</span>
          <span style={{ fontFamily: "'Playfair Display', serif", fontSize: 22, fontWeight: 900, color: theme.textPrimary, letterSpacing: -0.5, position: "relative" }}>
            Book<span style={{ color: theme.accent }}>table</span>
            <span style={{ position: "absolute", bottom: -2, left: 0, right: 0, height: 1, background: `linear-gradient(90deg, ${theme.accent}, transparent)` }} />
          </span>
        </div>
      </div>
      <nav style={{ display: "flex", gap: 32, alignItems: "center" }}>
        {[
          { key: "home", label: "Search" },
          { key: "reservations", label: "My Reservations" },
        ].map(item => (
          <span key={item.key} onClick={() => onNavigate(item.key)} style={{
            fontFamily: "'DM Sans', sans-serif", fontSize: 14, fontWeight: 500,
            color: currentPage === item.key ? theme.accent : theme.textSecondary,
            cursor: "pointer", transition: "color 0.2s",
            borderBottom: currentPage === item.key ? `2px solid ${theme.accent}` : "2px solid transparent",
            paddingBottom: 4,
          }}>
            {item.label}
          </span>
        ))}
        <div style={{
          width: 34, height: 34, borderRadius: "50%", background: theme.bgElevated,
          display: "flex", alignItems: "center", justifyContent: "center",
          border: `1px solid ${theme.borderAccent}`, cursor: "pointer",
          fontFamily: "'DM Sans', sans-serif", fontSize: 13, fontWeight: 600, color: theme.accent,
        }}>A</div>
      </nav>
    </header>
  );
}

function HomePage({ onNavigate }) {
  const [city, setCity] = useState("San Francisco");
  const [date, setDate] = useState("2026-02-10");
  const [time, setTime] = useState("19:00");
  const [guests, setGuests] = useState("2");
  const [loaded, setLoaded] = useState(false);

  useEffect(() => { setTimeout(() => setLoaded(true), 100); }, []);

  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column" }}>
      <div style={{
        flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
        padding: "80px 32px 40px",
        background: `radial-gradient(ellipse at 50% 30%, ${theme.accentGlow} 0%, transparent 60%)`,
      }}>
        <h1 style={{
          fontFamily: "'Playfair Display', serif", fontSize: 64, fontWeight: 400,
          color: theme.textPrimary, marginBottom: 12, textAlign: "center",
          opacity: loaded ? 1 : 0, transform: loaded ? "translateY(0)" : "translateY(20px)",
          transition: "all 0.8s cubic-bezier(0.16, 1, 0.3, 1)",
          letterSpacing: -1,
        }}>
          Your table awaits
        </h1>
        <p style={{
          fontFamily: "'DM Sans', sans-serif", fontSize: 17, color: theme.textTertiary,
          marginBottom: 48, textAlign: "center",
          opacity: loaded ? 1 : 0, transform: loaded ? "translateY(0)" : "translateY(20px)",
          transition: "all 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.15s",
        }}>
          Discover and reserve at San Francisco's finest restaurants
        </p>

        <div style={{
          display: "flex", gap: 1, borderRadius: 16, overflow: "hidden",
          background: theme.border, padding: 1,
          boxShadow: `0 0 60px ${theme.accentGlow}, 0 20px 40px rgba(0,0,0,0.4)`,
          opacity: loaded ? 1 : 0, transform: loaded ? "translateY(0)" : "translateY(20px)",
          transition: "all 0.8s cubic-bezier(0.16, 1, 0.3, 1) 0.3s",
          backdropFilter: "blur(20px)",
        }}>
          {[
            { label: "City", value: city, onChange: setCity, type: "text", width: 180 },
            { label: "Date", value: date, onChange: setDate, type: "date", width: 160 },
            { label: "Time", value: time, onChange: setTime, type: "time", width: 130 },
            { label: "Guests", value: guests, onChange: setGuests, type: "number", width: 90 },
          ].map((field, i) => (
            <div key={i} style={{ background: theme.bgSecondary, padding: "14px 20px", width: field.width }}>
              <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 10, fontWeight: 600, color: theme.textTertiary, textTransform: "uppercase", letterSpacing: 1.5, marginBottom: 6 }}>
                {field.label}
              </div>
              <input type={field.type} value={field.value} onChange={e => field.onChange(e.target.value)} style={{
                background: "transparent", border: "none", outline: "none", width: "100%",
                fontFamily: "'DM Sans', sans-serif", fontSize: 15, color: theme.textPrimary,
              }} />
            </div>
          ))}
          <button onClick={() => onNavigate("search")} style={{
            background: `linear-gradient(135deg, ${theme.accent}, ${theme.accentWarm})`,
            border: "none", padding: "14px 32px", cursor: "pointer",
            fontFamily: "'DM Sans', sans-serif", fontSize: 15, fontWeight: 600, color: theme.bgPrimary,
            display: "flex", alignItems: "center", gap: 8, transition: "all 0.2s",
            whiteSpace: "nowrap",
          }}>
            Find tables
            <span style={{ fontSize: 18 }}>→</span>
          </button>
        </div>
      </div>

      <div style={{
        padding: "40px 32px 60px", maxWidth: 1100, margin: "0 auto", width: "100%",
        opacity: loaded ? 1 : 0, transition: "opacity 0.8s ease 0.6s",
      }}>
        <h2 style={{ fontFamily: "'Playfair Display', serif", fontSize: 28, color: theme.textPrimary, marginBottom: 8 }}>
          Trending tonight
        </h2>
        <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: theme.textTertiary, marginBottom: 28 }}>
          Popular reservations in San Francisco
        </p>
        <div style={{ display: "flex", gap: 20, overflowX: "auto", paddingBottom: 16 }}>
          {restaurants.slice(0, 4).map((r, i) => (
            <div key={r.id} onClick={() => onNavigate("detail", r)} style={{
              minWidth: 240, borderRadius: 14, overflow: "hidden", cursor: "pointer",
              background: theme.bgSecondary, border: `1px solid ${theme.border}`,
              transition: "all 0.3s ease", flexShrink: 0,
              opacity: loaded ? 1 : 0, transform: loaded ? "translateX(0)" : "translateX(30px)",
              transitionDelay: `${0.7 + i * 0.1}s`,
            }} onMouseEnter={e => { e.currentTarget.style.transform = "translateY(-4px)"; e.currentTarget.style.boxShadow = `0 12px 30px rgba(0,0,0,0.4)`; }}
               onMouseLeave={e => { e.currentTarget.style.transform = "translateY(0)"; e.currentTarget.style.boxShadow = "none"; }}>
              <div style={{
                height: 140, background: `linear-gradient(135deg, ${theme.bgElevated}, ${theme.bgHover})`,
                display: "flex", alignItems: "center", justifyContent: "center", fontSize: 48,
              }}>{r.image}</div>
              <div style={{ padding: "16px 18px" }}>
                <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 17, fontWeight: 600, color: theme.textPrimary, marginBottom: 6 }}>{r.name}</div>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 10 }}>
                  <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textSecondary }}>{r.cuisine}</span>
                  <PriceLevel level={r.price} />
                </div>
                <StarRating rating={r.rating} />
                <div style={{ display: "flex", gap: 6, marginTop: 12, flexWrap: "wrap" }}>
                  {r.times.slice(0, 3).map(t => (
                    <span key={t} style={{
                      fontFamily: "'JetBrains Mono', monospace", fontSize: 11,
                      padding: "5px 10px", borderRadius: 8, border: `1px solid ${theme.borderAccent}`,
                      color: theme.accent, background: theme.accentGlow,
                    }}>{t}</span>
                  ))}
                  {r.times.length > 3 && (
                    <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, color: theme.textTertiary, padding: "5px 4px" }}>+{r.times.length - 3}</span>
                  )}
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function SearchPage({ onNavigate }) {
  const [selectedCuisine, setSelectedCuisine] = useState("All");
  const cuisines = ["All", "Japanese", "Californian", "French", "Mexican", "Modern American", "Bakery & Cafe"];
  const filtered = selectedCuisine === "All" ? restaurants : restaurants.filter(r => r.cuisine === selectedCuisine);

  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <aside style={{
        width: 240, padding: "28px 24px", borderRight: `1px solid ${theme.border}`,
        background: theme.bgSecondary, position: "sticky", top: 65, height: "calc(100vh - 65px)",
        overflowY: "auto", flexShrink: 0,
      }}>
        <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, fontWeight: 600, color: theme.textTertiary, textTransform: "uppercase", letterSpacing: 1.5, marginBottom: 16 }}>Cuisine</div>
        {cuisines.map(c => (
          <div key={c} onClick={() => setSelectedCuisine(c)} style={{
            fontFamily: "'DM Sans', sans-serif", fontSize: 14, padding: "8px 12px", marginBottom: 2,
            borderRadius: 8, cursor: "pointer", transition: "all 0.2s",
            color: selectedCuisine === c ? theme.accent : theme.textSecondary,
            background: selectedCuisine === c ? theme.accentGlow : "transparent",
          }}>{c}</div>
        ))}

        <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, fontWeight: 600, color: theme.textTertiary, textTransform: "uppercase", letterSpacing: 1.5, marginTop: 32, marginBottom: 16 }}>Price</div>
        <div style={{ display: "flex", gap: 6 }}>
          {[1,2,3,4].map(p => (
            <button key={p} style={{
              fontFamily: "'DM Sans', sans-serif", fontSize: 13, padding: "6px 12px",
              borderRadius: 8, border: `1px solid ${theme.border}`, cursor: "pointer",
              background: "transparent", color: theme.textSecondary, transition: "all 0.2s",
            }}>{"$".repeat(p)}</button>
          ))}
        </div>

        <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, fontWeight: 600, color: theme.textTertiary, textTransform: "uppercase", letterSpacing: 1.5, marginTop: 32, marginBottom: 16 }}>Rating</div>
        <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
          {[1,2,3,4,5].map(i => (
            <span key={i} style={{ fontSize: 18, color: i <= 4 ? theme.accent : theme.bgHover, cursor: "pointer" }}>★</span>
          ))}
          <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textSecondary }}>& up</span>
        </div>
      </aside>

      <main style={{ flex: 1, padding: "28px 32px" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 24 }}>
          <div>
            <h2 style={{ fontFamily: "'Playfair Display', serif", fontSize: 28, color: theme.textPrimary, marginBottom: 4 }}>San Francisco</h2>
            <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textTertiary }}>
              {filtered.length} restaurants · Tue, Feb 10 · 7:00 PM · 2 guests
            </span>
          </div>
          <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textSecondary }}>Sort: Top Rated</span>
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 20 }}>
          {filtered.map((r, i) => (
            <div key={r.id} onClick={() => onNavigate("detail", r)} style={{
              borderRadius: 14, overflow: "hidden", cursor: "pointer",
              background: theme.bgSecondary, border: `1px solid ${theme.border}`,
              transition: "all 0.3s ease",
              animation: `fadeSlideUp 0.5s ease ${i * 0.08}s both`,
            }} onMouseEnter={e => { e.currentTarget.style.transform = "translateY(-3px)"; e.currentTarget.style.borderColor = theme.borderAccent; }}
               onMouseLeave={e => { e.currentTarget.style.transform = "translateY(0)"; e.currentTarget.style.borderColor = theme.border; }}>
              <div style={{
                height: 160, background: `linear-gradient(135deg, ${theme.bgElevated}, ${theme.bgHover})`,
                display: "flex", alignItems: "center", justifyContent: "center", fontSize: 56,
                position: "relative",
              }}>
                {r.image}
                <div style={{
                  position: "absolute", top: 12, right: 12, background: `${theme.bgPrimary}cc`,
                  borderRadius: 8, padding: "4px 10px", backdropFilter: "blur(10px)",
                }}>
                  <StarRating rating={r.rating} />
                </div>
              </div>
              <div style={{ padding: "18px 20px" }}>
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 4 }}>
                  <span style={{ fontFamily: "'Playfair Display', serif", fontSize: 19, fontWeight: 600, color: theme.textPrimary }}>{r.name}</span>
                  <PriceLevel level={r.price} />
                </div>
                <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textSecondary, marginBottom: 14 }}>
                  {r.cuisine} · {r.address}
                </div>
                <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                  {r.times.map(t => (
                    <span key={t} onClick={e => { e.stopPropagation(); onNavigate("booking", { ...r, selectedTime: t }); }} style={{
                      fontFamily: "'JetBrains Mono', monospace", fontSize: 12,
                      padding: "7px 14px", borderRadius: 8, border: `1px solid ${theme.borderAccent}`,
                      color: theme.accent, background: theme.accentGlow,
                      transition: "all 0.2s", cursor: "pointer",
                    }} onMouseEnter={e => { e.currentTarget.style.background = theme.accent; e.currentTarget.style.color = theme.bgPrimary; }}
                       onMouseLeave={e => { e.currentTarget.style.background = theme.accentGlow; e.currentTarget.style.color = theme.accent; }}>
                      {t}
                    </span>
                  ))}
                </div>
              </div>
            </div>
          ))}
        </div>
      </main>
      <style>{`@keyframes fadeSlideUp { from { opacity: 0; transform: translateY(16px); } to { opacity: 1; transform: translateY(0); } }`}</style>
    </div>
  );
}

function DetailPage({ restaurant, onNavigate }) {
  const r = restaurant || restaurants[0];
  const [activeTab, setActiveTab] = useState("All");
  const tabs = ["All Seating", "Main Dining", "Patio", "Bar"];

  return (
    <div style={{ maxWidth: 900, margin: "0 auto", padding: "0 32px 60px" }}>
      <div style={{
        height: 300, borderRadius: "0 0 20px 20px", overflow: "hidden",
        background: `linear-gradient(135deg, ${theme.bgElevated} 0%, ${theme.bgHover} 50%, ${theme.bgElevated} 100%)`,
        display: "flex", alignItems: "center", justifyContent: "center", fontSize: 100,
        position: "relative",
      }}>
        {r.image}
        <div style={{
          position: "absolute", bottom: 0, left: 0, right: 0, padding: "60px 32px 24px",
          background: `linear-gradient(transparent, ${theme.bgPrimary})`,
        }}>
          <h1 style={{ fontFamily: "'Playfair Display', serif", fontSize: 40, fontWeight: 700, color: theme.textPrimary, marginBottom: 8 }}>{r.name}</h1>
          <div style={{ display: "flex", gap: 16, alignItems: "center" }}>
            <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: theme.textSecondary }}>{r.cuisine}</span>
            <span style={{ color: theme.borderAccent }}>·</span>
            <PriceLevel level={r.price} />
            <span style={{ color: theme.borderAccent }}>·</span>
            <StarRating rating={r.rating} />
          </div>
        </div>
      </div>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 300px", gap: 40, marginTop: 32 }}>
        <div>
          <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 15, color: theme.textSecondary, lineHeight: 1.7, marginBottom: 32 }}>{r.desc}</p>

          <h3 style={{ fontFamily: "'Playfair Display', serif", fontSize: 24, color: theme.textPrimary, marginBottom: 20 }}>
            Choose your table
          </h3>

          <div style={{ display: "flex", gap: 0, borderBottom: `1px solid ${theme.border}`, marginBottom: 24 }}>
            {tabs.map(tab => (
              <button key={tab} onClick={() => setActiveTab(tab)} style={{
                fontFamily: "'DM Sans', sans-serif", fontSize: 13, fontWeight: 500,
                padding: "10px 20px", border: "none", cursor: "pointer",
                color: activeTab === tab ? theme.accent : theme.textTertiary,
                background: "transparent",
                borderBottom: activeTab === tab ? `2px solid ${theme.accent}` : "2px solid transparent",
                transition: "all 0.2s", marginBottom: -1,
              }}>{tab}</button>
            ))}
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr 1fr", gap: 10 }}>
            {r.times.map(t => (
              <div key={t} onClick={() => onNavigate("booking", { ...r, selectedTime: t })} style={{
                padding: "16px", borderRadius: 12, border: `1px solid ${theme.border}`,
                background: theme.bgSecondary, cursor: "pointer", transition: "all 0.2s",
                textAlign: "center",
              }} onMouseEnter={e => { e.currentTarget.style.borderColor = theme.accent; e.currentTarget.style.background = theme.accentGlow; }}
                 onMouseLeave={e => { e.currentTarget.style.borderColor = theme.border; e.currentTarget.style.background = theme.bgSecondary; }}>
                <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 16, color: theme.textPrimary, marginBottom: 4 }}>{t}</div>
                <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, color: theme.textTertiary }}>Table for 2</div>
              </div>
            ))}
          </div>
        </div>

        <div style={{ position: "sticky", top: 90 }}>
          <div style={{ background: theme.bgSecondary, borderRadius: 16, padding: 24, border: `1px solid ${theme.border}` }}>
            <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, fontWeight: 600, color: theme.textTertiary, textTransform: "uppercase", letterSpacing: 1.5, marginBottom: 16 }}>Details</div>
            {[
              { icon: "📍", label: r.address },
              { icon: "🕐", label: "Tue–Sun, 5:30 PM – 10:00 PM" },
              { icon: "👥", label: "Party of 2" },
              { icon: "💳", label: "$50 deposit required" },
            ].map((item, i) => (
              <div key={i} style={{ display: "flex", gap: 10, marginBottom: 12, fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textSecondary }}>
                <span>{item.icon}</span><span>{item.label}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function CountdownTimer({ seconds, total }) {
  const radius = 80;
  const circumference = 2 * Math.PI * radius;
  const progress = seconds / total;
  const isUrgent = seconds < 60;

  return (
    <div style={{ position: "relative", width: 200, height: 200 }}>
      <svg width="200" height="200" style={{ transform: "rotate(-90deg)" }}>
        <circle cx="100" cy="100" r={radius} fill="none" stroke={theme.bgElevated} strokeWidth="4" />
        <circle cx="100" cy="100" r={radius} fill="none"
          stroke={isUrgent ? theme.danger : theme.accent}
          strokeWidth="4" strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - progress)}
          style={{ transition: "stroke-dashoffset 1s linear, stroke 0.5s ease",
                   filter: `drop-shadow(0 0 8px ${isUrgent ? theme.danger : theme.accent}40)` }}
        />
      </svg>
      <div style={{
        position: "absolute", top: "50%", left: "50%", transform: "translate(-50%, -50%)",
        textAlign: "center",
      }}>
        <div style={{
          fontFamily: "'JetBrains Mono', monospace", fontSize: 36, fontWeight: 500,
          color: isUrgent ? theme.danger : theme.textPrimary,
          animation: isUrgent ? "pulse 1s ease infinite" : "none",
        }}>
          {Math.floor(seconds / 60)}:{String(seconds % 60).padStart(2, "0")}
        </div>
        <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, color: theme.textTertiary, marginTop: 2 }}>remaining</div>
      </div>
    </div>
  );
}

function BookingPage({ restaurant, onNavigate }) {
  const r = restaurant || { ...restaurants[0], selectedTime: "7:00 PM" };
  const [step, setStep] = useState("hold"); // hold, payment, confirmed
  const [countdown, setCountdown] = useState(277);
  const [confirmAnim, setConfirmAnim] = useState(false);

  useEffect(() => {
    if (step !== "hold" && step !== "payment") return;
    const timer = setInterval(() => setCountdown(c => Math.max(0, c - 1)), 1000);
    return () => clearInterval(timer);
  }, [step]);

  useEffect(() => {
    if (step === "confirmed") setTimeout(() => setConfirmAnim(true), 100);
  }, [step]);

  if (step === "confirmed") {
    return (
      <div style={{
        minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center",
        padding: 32, background: `radial-gradient(ellipse at 50% 40%, rgba(34, 197, 94, 0.08) 0%, transparent 60%)`,
      }}>
        <div style={{
          opacity: confirmAnim ? 1 : 0, transform: confirmAnim ? "scale(1)" : "scale(0.8)",
          transition: "all 0.6s cubic-bezier(0.16, 1, 0.3, 1)",
        }}>
          <svg width="80" height="80" viewBox="0 0 80 80" style={{ display: "block", margin: "0 auto 24px" }}>
            <circle cx="40" cy="40" r="38" fill="none" stroke={theme.success} strokeWidth="2"
              style={{ opacity: confirmAnim ? 1 : 0, transition: "opacity 0.4s ease 0.2s" }} />
            <path d="M24 40 L35 51 L56 30" fill="none" stroke={theme.success} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"
              strokeDasharray="50" strokeDashoffset={confirmAnim ? 0 : 50}
              style={{ transition: "stroke-dashoffset 0.6s ease 0.4s" }} />
          </svg>
        </div>
        <h2 style={{
          fontFamily: "'Playfair Display', serif", fontSize: 32, color: theme.textPrimary, marginBottom: 8,
          opacity: confirmAnim ? 1 : 0, transition: "opacity 0.5s ease 0.6s",
        }}>Reservation confirmed</h2>
        <p style={{
          fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: theme.textTertiary, marginBottom: 32,
          opacity: confirmAnim ? 1 : 0, transition: "opacity 0.5s ease 0.7s",
        }}>We've sent a confirmation to your email</p>

        <div style={{
          background: theme.bgSecondary, borderRadius: 16, padding: 32, width: 380,
          border: `1px solid ${theme.border}`, textAlign: "center",
          opacity: confirmAnim ? 1 : 0, transform: confirmAnim ? "translateY(0)" : "translateY(20px)",
          transition: "all 0.6s ease 0.8s",
        }}>
          <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, fontWeight: 600, color: theme.textTertiary, textTransform: "uppercase", letterSpacing: 2, marginBottom: 12 }}>Confirmation Code</div>
          <div style={{
            fontFamily: "'JetBrains Mono', monospace", fontSize: 40, fontWeight: 500, color: theme.accent,
            letterSpacing: 8, marginBottom: 24,
          }}>ABC123</div>
          <div style={{ width: "100%", height: 1, background: theme.border, marginBottom: 20 }} />
          {[
            { label: "Restaurant", value: r.name },
            { label: "Date", value: "Tuesday, February 10, 2026" },
            { label: "Time", value: r.selectedTime },
            { label: "Guests", value: "2" },
            { label: "Deposit", value: "$50.00" },
          ].map((item, i) => (
            <div key={i} style={{ display: "flex", justifyContent: "space-between", marginBottom: 10 }}>
              <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textTertiary }}>{item.label}</span>
              <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textPrimary, fontWeight: 500 }}>{item.value}</span>
            </div>
          ))}
          <div style={{ display: "flex", gap: 10, marginTop: 24 }}>
            <button style={{
              flex: 1, padding: "12px", borderRadius: 10, border: `1px solid ${theme.border}`,
              background: "transparent", color: theme.textSecondary, cursor: "pointer",
              fontFamily: "'DM Sans', sans-serif", fontSize: 13, fontWeight: 500,
            }}>Add to Calendar</button>
            <button onClick={() => onNavigate("reservations")} style={{
              flex: 1, padding: "12px", borderRadius: 10, border: "none",
              background: theme.accent, color: theme.bgPrimary, cursor: "pointer",
              fontFamily: "'DM Sans', sans-serif", fontSize: 13, fontWeight: 600,
            }}>My Reservations</button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{
      minHeight: "100vh", display: "flex", flexDirection: "column", alignItems: "center",
      padding: "60px 32px",
      background: `radial-gradient(ellipse at 50% 20%, ${theme.accentGlow} 0%, transparent 50%)`,
    }}>
      <CountdownTimer seconds={countdown} total={300} />

      <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: theme.textTertiary, marginTop: 16, marginBottom: 8 }}>
        Your table is held
      </p>
      <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textTertiary, marginBottom: 32, opacity: 0.6 }}>
        🛡️ Layer 1: Redis SETNX hold — 5 minute protection
      </p>

      <div style={{
        background: theme.bgSecondary, borderRadius: 16, padding: 32, width: 420,
        border: `1px solid ${theme.border}`,
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 20, paddingBottom: 16, borderBottom: `1px solid ${theme.border}` }}>
          <div>
            <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 20, color: theme.textPrimary }}>{r.name}</div>
            <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textSecondary, marginTop: 4 }}>
              {r.selectedTime} · 2 guests · Table 5 (Booth)
            </div>
          </div>
          <div style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: theme.accent, padding: "6px 12px", background: theme.accentGlow, borderRadius: 8, alignSelf: "flex-start" }}>
            $50
          </div>
        </div>

        {step === "hold" && (
          <div style={{ animation: "fadeSlideUp 0.3s ease" }}>
            <div style={{ marginBottom: 16 }}>
              <label style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textTertiary, display: "block", marginBottom: 6 }}>Special Requests</label>
              <textarea placeholder="Allergies, celebrations, seating preferences..." rows={3} style={{
                width: "100%", padding: "12px 14px", borderRadius: 10, border: `1px solid ${theme.border}`,
                background: theme.bgElevated, color: theme.textPrimary, outline: "none", resize: "none",
                fontFamily: "'DM Sans', sans-serif", fontSize: 14, boxSizing: "border-box",
              }} />
            </div>
            <button onClick={() => setStep("payment")} style={{
              width: "100%", padding: "14px", borderRadius: 12, border: "none", cursor: "pointer",
              background: `linear-gradient(135deg, ${theme.accent}, ${theme.accentWarm})`,
              fontFamily: "'DM Sans', sans-serif", fontSize: 15, fontWeight: 600, color: theme.bgPrimary,
            }}>
              Continue to Payment →
            </button>
          </div>
        )}

        {step === "payment" && (
          <div style={{ animation: "fadeSlideUp 0.3s ease" }}>
            <div style={{ marginBottom: 16 }}>
              <label style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textTertiary, display: "block", marginBottom: 6 }}>Card Number</label>
              <input placeholder="4242 4242 4242 4242" style={{
                width: "100%", padding: "12px 14px", borderRadius: 10, border: `1px solid ${theme.border}`,
                background: theme.bgElevated, color: theme.textPrimary, outline: "none",
                fontFamily: "'JetBrains Mono', monospace", fontSize: 14, boxSizing: "border-box",
              }} />
            </div>
            <div style={{ display: "flex", gap: 12, marginBottom: 20 }}>
              <div style={{ flex: 1 }}>
                <label style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textTertiary, display: "block", marginBottom: 6 }}>Expiry</label>
                <input placeholder="MM/YY" style={{
                  width: "100%", padding: "12px 14px", borderRadius: 10, border: `1px solid ${theme.border}`,
                  background: theme.bgElevated, color: theme.textPrimary, outline: "none",
                  fontFamily: "'JetBrains Mono', monospace", fontSize: 14, boxSizing: "border-box",
                }} />
              </div>
              <div style={{ flex: 1 }}>
                <label style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.textTertiary, display: "block", marginBottom: 6 }}>CVC</label>
                <input placeholder="123" style={{
                  width: "100%", padding: "12px 14px", borderRadius: 10, border: `1px solid ${theme.border}`,
                  background: theme.bgElevated, color: theme.textPrimary, outline: "none",
                  fontFamily: "'JetBrains Mono', monospace", fontSize: 14, boxSizing: "border-box",
                }} />
              </div>
            </div>
            <div style={{
              padding: "10px 14px", borderRadius: 10, background: theme.accentGlow,
              fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.accent, marginBottom: 16,
              border: `1px solid ${theme.borderAccent}`,
            }}>
              🛡️ Defense layers active: Redis Hold (L1) · DB Constraint (L2) · Idempotency Key (L3)
            </div>
            <button onClick={() => setStep("confirmed")} style={{
              width: "100%", padding: "14px", borderRadius: 12, border: "none", cursor: "pointer",
              background: `linear-gradient(135deg, ${theme.accent}, ${theme.accentWarm})`,
              fontFamily: "'DM Sans', sans-serif", fontSize: 15, fontWeight: 600, color: theme.bgPrimary,
            }}>
              Confirm Booking · $50 deposit
            </button>
            <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, color: theme.textTertiary, textAlign: "center", marginTop: 12 }}>
              Secured with Stripe · PCI compliant · Idempotent
            </p>
          </div>
        )}
      </div>

      <button onClick={() => onNavigate("detail", r)} style={{
        background: "none", border: "none", color: theme.textTertiary, cursor: "pointer",
        fontFamily: "'DM Sans', sans-serif", fontSize: 13, marginTop: 20,
      }}>
        Release table & go back
      </button>
      <style>{`
        @keyframes fadeSlideUp { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: translateY(0); } }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.6; } }
      `}</style>
    </div>
  );
}

function ReservationsPage({ onNavigate }) {
  const reservations = [
    { id: 1, restaurant: "The Sushi Bar", code: "ABC123", date: "Feb 10, 2026", time: "7:00 PM", guests: 2, status: "CONFIRMED", emoji: "🍣" },
    { id: 2, restaurant: "Atelier Crenn", code: "XYZ789", date: "Feb 14, 2026", time: "8:00 PM", guests: 2, status: "CONFIRMED", emoji: "🇫🇷" },
    { id: 3, restaurant: "Nopa", code: "DEF456", date: "Jan 28, 2026", time: "7:30 PM", guests: 4, status: "COMPLETED", emoji: "🥘" },
    { id: 4, restaurant: "La Taqueria", code: "GHI012", date: "Jan 15, 2026", time: "6:00 PM", guests: 3, status: "CANCELLED", emoji: "🌮" },
  ];

  const statusColors = {
    CONFIRMED: { bg: theme.accentGlow, border: theme.borderAccent, text: theme.accent, dot: theme.accent },
    COMPLETED: { bg: "rgba(34,197,94,0.1)", border: "rgba(34,197,94,0.3)", text: theme.success, dot: theme.success },
    CANCELLED: { bg: "rgba(239,68,68,0.1)", border: "rgba(239,68,68,0.3)", text: theme.danger, dot: theme.danger },
  };

  return (
    <div style={{ maxWidth: 700, margin: "0 auto", padding: "32px" }}>
      <h2 style={{ fontFamily: "'Playfair Display', serif", fontSize: 32, color: theme.textPrimary, marginBottom: 8 }}>My Reservations</h2>
      <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: theme.textTertiary, marginBottom: 32 }}>Upcoming and past bookings</p>

      {reservations.map((res, i) => {
        const sc = statusColors[res.status];
        const isPast = res.status !== "CONFIRMED";
        return (
          <div key={res.id} style={{
            display: "flex", gap: 20, padding: "20px 24px", borderRadius: 14,
            background: theme.bgSecondary, border: `1px solid ${theme.border}`,
            marginBottom: 12, opacity: isPast ? 0.6 : 1,
            borderLeft: `3px solid ${sc.dot}`, transition: "all 0.2s",
            animation: `fadeSlideUp 0.4s ease ${i * 0.08}s both`,
          }}>
            <div style={{
              width: 52, height: 52, borderRadius: 12, background: theme.bgElevated,
              display: "flex", alignItems: "center", justifyContent: "center", fontSize: 26, flexShrink: 0,
            }}>{res.emoji}</div>
            <div style={{ flex: 1 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                <div>
                  <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 17, color: theme.textPrimary }}>{res.restaurant}</div>
                  <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: theme.textSecondary, marginTop: 3 }}>
                    {res.date} · {res.time} · {res.guests} guests
                  </div>
                </div>
                <span style={{
                  fontFamily: "'DM Sans', sans-serif", fontSize: 11, fontWeight: 600, padding: "4px 12px",
                  borderRadius: 20, background: sc.bg, color: sc.text, border: `1px solid ${sc.border}`,
                  textTransform: "uppercase", letterSpacing: 0.5,
                }}>{res.status}</span>
              </div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 10 }}>
                <span style={{ fontFamily: "'JetBrains Mono', monospace", fontSize: 13, color: theme.textTertiary }}>
                  #{res.code}
                </span>
                {res.status === "CONFIRMED" && (
                  <button style={{
                    fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: theme.danger,
                    background: "none", border: "none", cursor: "pointer", padding: "4px 0",
                  }}>Cancel reservation</button>
                )}
              </div>
            </div>
          </div>
        );
      })}
      <style>{`@keyframes fadeSlideUp { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: translateY(0); } }`}</style>
    </div>
  );
}

export default function App() {
  const [page, setPage] = useState("home");
  const [selectedRestaurant, setSelectedRestaurant] = useState(null);

  const navigate = (target, data) => {
    if (data) setSelectedRestaurant(data);
    setPage(target);
    window.scrollTo(0, 0);
  };

  return (
    <div style={{ background: theme.bgPrimary, minHeight: "100vh", color: theme.textPrimary, fontFamily: "'DM Sans', sans-serif" }}>
      <GrainOverlay />
      <div style={{ position: "relative", zIndex: 2 }}>
        <Header currentPage={page} onNavigate={navigate} />
        {page === "home" && <HomePage onNavigate={navigate} />}
        {page === "search" && <SearchPage onNavigate={navigate} />}
        {page === "detail" && <DetailPage restaurant={selectedRestaurant} onNavigate={navigate} />}
        {page === "booking" && <BookingPage restaurant={selectedRestaurant} onNavigate={navigate} />}
        {page === "reservations" && <ReservationsPage onNavigate={navigate} />}
      </div>
    </div>
  );
}
