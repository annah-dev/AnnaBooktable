import axios from 'axios';

const api = axios.create({
  baseURL: (import.meta.env.VITE_API_URL ?? 'http://localhost:5000') + '/api',
  headers: { 'Content-Type': 'application/json' },
  timeout: 10000,
});

export default api;

// Shared response type from the backend
export interface ApiResponse<T> {
  success: boolean;
  data: T;
  error?: string;
  timestamp: string;
}
