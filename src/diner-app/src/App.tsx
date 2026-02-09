import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import Header from './components/layout/Header.tsx';
import HomePage from './pages/HomePage.tsx';
import SearchResultsPage from './pages/SearchResultsPage.tsx';
import RestaurantDetailPage from './pages/RestaurantDetailPage.tsx';
import BookingPage from './pages/BookingPage.tsx';
import ReservationsPage from './pages/ReservationsPage.tsx';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
    },
  },
});

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <div className="bg-bg-primary min-h-screen text-text-primary font-sans">
          <div className="grain-overlay" />
          <div className="relative z-[2]">
            <Header />
            <Routes>
              <Route path="/" element={<HomePage />} />
              <Route path="/search" element={<SearchResultsPage />} />
              <Route path="/restaurant/:id" element={<RestaurantDetailPage />} />
              <Route path="/book/:slotId" element={<BookingPage />} />
              <Route path="/reservations" element={<ReservationsPage />} />
            </Routes>
          </div>
        </div>
      </BrowserRouter>
    </QueryClientProvider>
  );
}
