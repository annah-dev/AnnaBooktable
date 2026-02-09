# Phase 2: Diner App - React Frontend Design Spec

## Design Vision: "Midnight Supper Club"

A **luxury editorial** aesthetic inspired by high-end dining magazines and boutique hotel booking apps. Dark mode by default with warm amber accents — feels like candlelight on dark wood. This is NOT a generic restaurant finder. It feels like an exclusive invitation to the city's best tables.

### Design Personality
- **Tone:** Refined, confident, intimate — like a maître d' who knows your name
- **Inspiration:** Resy's dark mode meets Aesop's typography meets The Infatuation's editorial voice
- **Memorable detail:** The 5-minute hold countdown is a glowing amber ring that slowly depletes — like a candle burning down

---

## Color Palette

```css
:root {
  /* Core */
  --bg-primary: #0C0A09;        /* Almost black, warm undertone */
  --bg-secondary: #1C1917;      /* Dark warm gray (stone-900) */
  --bg-elevated: #292524;       /* Elevated surfaces (stone-800) */
  --bg-hover: #44403C;          /* Hover state (stone-700) */
  
  /* Text */
  --text-primary: #FAFAF9;      /* Off-white (stone-50) */
  --text-secondary: #A8A29E;    /* Muted (stone-400) */
  --text-tertiary: #78716C;     /* Subtle (stone-500) */
  
  /* Accent - Amber (candlelight) */
  --accent: #F59E0B;            /* Amber-500 */
  --accent-warm: #D97706;       /* Amber-600 */
  --accent-glow: rgba(245, 158, 11, 0.15);  /* Soft glow */
  
  /* Status */
  --success: #22C55E;           /* Green-500 */
  --danger: #EF4444;            /* Red-500 */
  --warning: #F59E0B;           /* Amber-500 */
  
  /* Borders */
  --border: #292524;            /* Subtle */
  --border-accent: rgba(245, 158, 11, 0.3);  /* Amber glow border */
}
```

## Typography

**Display / Headlines:** "Playfair Display" — elegant serif with personality
**Body / UI:** "DM Sans" — clean geometric sans-serif, modern
**Mono / Data:** "JetBrains Mono" — for confirmation codes, times

```html
<link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;600;700;900&family=DM+Sans:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

```css
font-family: 'DM Sans', sans-serif;         /* Body default */
font-family: 'Playfair Display', serif;      /* Headlines */
font-family: 'JetBrains Mono', monospace;    /* Codes, times */
```

---

## Pages & Components

### 1. Landing / Search Page (`/`)

**Layout:** Full-screen dark canvas with centered search.

**Hero Section:**
- Large Playfair Display headline: "Your table awaits"
- Subheading: "Anna's Booktable — reserve at the city's finest"
- Subtle animated grain texture overlay on background
- Search bar: frosted glass effect (backdrop-blur), amber focus ring
- Inputs: City, Date, Time, Party Size — horizontal row
- Search button: solid amber with subtle hover glow animation

**Below Search:**
- "Trending Tonight" section — horizontal scroll of restaurant cards
- Each card: cover image with dark gradient overlay, restaurant name, cuisine, rating stars in amber

**Animations:**
- Staggered fade-in on load (headline, then search, then trending)
- Search bar has a gentle pulse on the amber border when idle
- Cards slide in from right on scroll

### 2. Search Results Page (`/search`)

**Layout:** Left sidebar filters + right results grid

**Sidebar (sticky):**
- Cuisine checkboxes (with amber check marks)
- Price level: $$$ buttons
- Rating: star filter
- "Available Now" toggle
- All controls use amber accent on active state

**Results Grid:**
- 2-column card layout
- Each card:
  - Restaurant image (16:9 ratio, hover zoom)
  - Name in Playfair Display (20px)
  - Cuisine + Price in DM Sans (14px, muted)
  - Rating: amber stars + number
  - Available times: horizontal row of time pills
  - Time pills: dark bg, amber border, hover fills amber
  - Clicking a time pill goes directly to hold flow

**Empty State:**
- Elegant illustration (CSS-drawn plate and cutlery)
- "No tables match your search. Try adjusting your filters."

### 3. Restaurant Detail Page (`/restaurant/:id`)

**Layout:** Editorial magazine style

**Hero:**
- Full-width cover image with parallax scroll effect
- Restaurant name overlaid in large Playfair Display (48px)
- Cuisine | Price Level | Rating — amber dividers between

**Info Section:**
- Two columns: Left = description + amenities, Right = map + hours
- Operating hours in a clean table with today highlighted in amber
- Amenities as subtle icon badges

**Availability Section: "Choose Your Table"**
- Date picker: custom styled, amber selected date
- Time grid: Available slots shown as cards
  - Each card shows: Time, Table type (Patio/Main/Bar), Capacity
  - Available = dark card, amber border on hover
  - Held by someone else = muted, crossed out
  - Your hold = amber glow background

**Table Group Tabs (Bonus #2):**
- Horizontal tabs: "All Seating" | "Patio" | "Main Dining" | "Bar"
- Active tab has amber underline with smooth slide animation

### 4. Hold & Booking Flow (`/book/:slotId`)

**THE SHOWSTOPPER — This is what impresses interviewers**

**Step 1: Hold Acquired**
- Full-screen modal overlay with backdrop blur
- Large circular countdown timer in center:
  - Amber ring that depletes clockwise over 5 minutes
  - Time remaining in JetBrains Mono: "4:37"
  - Subtle pulse animation on the ring
  - Below: "Your table is held. Complete your booking."
- Restaurant name + time + table info below the timer
- "Release Table" link at bottom (subtle, not prominent)

**Step 2: Payment & Details**
- Slides in from right (or smooth transition)
- Party size confirmation
- Special requests text area (dark bg, amber focus)
- Payment card input (Stripe Elements styled to match theme)
- "Confirm Booking" button: 
  - Large, amber, full-width
  - On click: button morphs into a loading spinner
  - Timer still visible but smaller in top-right corner

**Step 3: Confirmation**
- Satisfying animation: amber checkmark draws itself (SVG path animation)
- Confirmation code in large JetBrains Mono: "ABC123"
- Confetti-like particle animation (amber/gold particles, subtle)
- Booking details card with all info
- "Add to Calendar" and "Share" buttons
- "Book Another Table" link

### 5. My Reservations Page (`/reservations`)

**Layout:** Timeline style

- Upcoming reservations: cards with amber left border
- Past reservations: muted, gray left border
- Each card:
  - Restaurant name (Playfair), Date/Time (JetBrains Mono)
  - Status badge: Confirmed (amber), Completed (green), Cancelled (red)
  - Confirmation code
  - Cancel button (only for upcoming, with confirmation modal)

---

## Key Components

### `<CountdownTimer />` — The Hero Component
```
Props: { expiresAt: Date, onExpire: () => void }
- SVG circle with stroke-dasharray animation
- Amber gradient stroke
- Pulses gently every 30 seconds
- Last 60 seconds: turns red, pulses faster
- On expire: smooth fade to "Time's up" with option to re-hold
```

### `<TimeSlotPill />` — Available Time Selector
```
Props: { time: string, available: boolean, held: boolean, onClick }
States:
- Available: dark bg, amber border, hover fills amber
- Held (someone else): muted, strikethrough
- Selected: solid amber bg, dark text
- Transition: 200ms ease-out on all states
```

### `<RestaurantCard />` — Search Result Card
```
Props: { restaurant, availableSlots, onTimeClick }
- Image with lazy loading + blur-up placeholder
- Hover: image zooms 105%, shadow deepens
- Available times as TimeSlotPill row
- Stagger animation on search results load
```

### `<GlassSearchBar />` — Frosted Glass Search Input
```
- backdrop-filter: blur(20px) saturate(180%)
- Subtle border with amber glow on focus
- Animated placeholder text
- City autocomplete dropdown (dark, amber highlight)
```

### `<StatusBadge />` — Reservation Status
```
- Confirmed: amber outline + amber dot
- Completed: green outline + green check
- Cancelled: red outline + red X
- No-Show: gray outline + gray dash
- Subtle scale animation on mount
```

---

## Animations & Micro-interactions

1. **Page transitions:** Fade + slight upward slide (200ms)
2. **Card hover:** Scale 1.02, shadow deepen, image zoom 1.05 (150ms)
3. **Button click:** Scale down to 0.97, then back (100ms)
4. **Search submit:** Button width shrinks to circle, spinner appears
5. **Hold timer:** Continuous ring depletion (CSS animation, 300s linear)
6. **Confirmation checkmark:** SVG path draw animation (800ms ease-out)
7. **Toast notifications:** Slide in from top-right, amber left border
8. **Skeleton loading:** Shimmer animation (dark bg, lighter sweep)

---

## Tech Stack

- React 18 + TypeScript
- React Router v6 (routing)
- TanStack Query (data fetching + caching)
- Tailwind CSS (utility classes) + custom CSS for animations
- Axios (HTTP client, configured for Gateway at localhost:5000)
- date-fns (date formatting)
- Framer Motion (page transitions + complex animations)

All already installed by the scaffold script in `src/diner-app/`.

---

## Responsive Breakpoints

- Mobile: < 640px (single column, bottom sheet for filters)
- Tablet: 640-1024px (2 columns, collapsible sidebar)
- Desktop: > 1024px (full layout with sticky sidebar)

---

## API Integration

All calls go through the Gateway at `http://localhost:5000`:

```typescript
// src/api/client.ts
import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:5000/api',
  headers: { 'Content-Type': 'application/json' }
});

// Search
api.get('/search', { params: { city, date, time, partySize } });

// Availability
api.get('/inventory/availability', { params: { restaurantId, date, partySize } });

// Hold
api.post('/inventory/hold', { slotId, userId });

// Book
api.post('/reservations', body, { headers: { 'Idempotency-Key': uuid } });

// My reservations
api.get('/reservations/user/{userId}');
```

---

## File Structure

```
src/diner-app/
  src/
    api/
      client.ts           # Axios instance
      search.ts           # Search API hooks
      inventory.ts        # Availability + hold hooks
      reservations.ts     # Booking + history hooks
    components/
      layout/
        Header.tsx        # Nav bar with logo
        Footer.tsx        # Minimal footer
      search/
        GlassSearchBar.tsx
        FilterSidebar.tsx
        RestaurantCard.tsx
        TimeSlotPill.tsx
      booking/
        CountdownTimer.tsx    # THE HERO COMPONENT
        BookingModal.tsx
        PaymentForm.tsx
        ConfirmationView.tsx
      common/
        StatusBadge.tsx
        StarRating.tsx
        Skeleton.tsx
        Toast.tsx
    pages/
      HomePage.tsx
      SearchResultsPage.tsx
      RestaurantDetailPage.tsx
      BookingPage.tsx
      ReservationsPage.tsx
    hooks/
      useCountdown.ts
      useDebounce.ts
    styles/
      globals.css           # CSS variables, fonts, grain texture
      animations.css        # Keyframes for custom animations
    App.tsx
    main.tsx
```

---

## What Makes This Impressive for Interviews

1. **The countdown timer** — visually demonstrates the Redis hold mechanism. Interviewer can SEE the 5-minute protection working.
2. **Real-time status** — slots visually change state (available -> held -> booked) proving the concurrency model.
3. **Dark luxury aesthetic** — looks nothing like a typical developer demo. Shows design sensibility.
4. **Graceful degradation** — if Redis is down, the UI adapts (no timer, "Reserve now" messaging).
5. **Confirmation code** — JetBrains Mono display feels production-quality.
6. **The booking animation** — checkmark draw + particles feels like a real app celebration moment.
