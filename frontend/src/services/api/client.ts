import type { ApiError, Dashboard, PublicToken, Queue, QueueDisplay, QueueToken, StaffUser } from '../../types';
const base = (import.meta.env.VITE_API_BASE_URL || 'http://localhost:3000/api/v1').replace(/\/$/, '');
const sessionKey = 'queueless_staff_session';
async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let response: Response;
  const token = localStorage.getItem(sessionKey);
  const headers = new Headers(init?.headers);
  if (init?.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json');
  const isPublicLookup = /^\/tokens\/[^/]+$/.test(path);
  const isPublicDisplay = /^\/display\/\d+$/.test(path);
  if (token && !path.startsWith('/auth/login') && !isPublicLookup && !isPublicDisplay) headers.set('Authorization', `Bearer ${token}`);
  try { response = await fetch(`${base}${path}`, { ...init, headers }); }
  catch { throw new Error('Could not reach QueueLess. Check that the API is running and try again.'); }
  if (response.status === 401 && !path.startsWith('/auth/login')) {
    localStorage.removeItem(sessionKey);
    window.dispatchEvent(new Event('queueless:unauthorized'));
  }
  const body = await response.json().catch(() => ({}));
  if (!response.ok) { const error = body as ApiError; throw new Error(error.error?.message || `Request failed (${response.status})`); }
  return body as T;
}
export const api = {
  hasSession: () => Boolean(localStorage.getItem(sessionKey)),
  login: async (username: string, password: string) => {
    const result = await request<{ token: string; user: StaffUser }>('/auth/login', { method: 'POST', body: JSON.stringify({ username, password }) });
    localStorage.setItem(sessionKey, result.token);
    return result.user;
  },
  me: () => request<{ user: StaffUser }>('/auth/me'),
  logout: async () => { try { await request<void>('/auth/logout', { method: 'DELETE' }); } finally { localStorage.removeItem(sessionKey); } },
  queues: (includeInactive = false) => request<{ queues: Queue[] }>(`/queues${includeInactive ? '?include_inactive=true' : ''}`),
  dashboard: (id: number) => request<Dashboard>(`/queues/${id}/dashboard`),
  tokens: (id: number) => request<{ tokens: QueueToken[] }>(`/queues/${id}/tokens`),
  createToken: (id: number, data: { customer_name: string; contact_number?: string; service_type: string; visit_requirements?: string; note?: string }) => request<{ token: QueueToken; public_lookup_token: string }>(`/queues/${id}/tokens`, { method: 'POST', body: JSON.stringify({ queue_token: data }) }),
  publicToken: (lookup: string) => request<PublicToken>(`/tokens/${encodeURIComponent(lookup)}`),
  queueDisplay: (id: number) => request<QueueDisplay>(`/display/${id}`),
  callNext: (id: number) => request<{ token: QueueToken }>(`/queues/${id}/call_next`, { method: 'POST' }),
  action: (id: number, action: 'complete' | 'skip' | 'return_to_waiting' | 'cancel') => request<{ token: QueueToken }>(`/tokens/${id}/${action}`, { method: 'PATCH' }),
  updateQueue: (id: number, data: Pick<Queue, 'name' | 'service_type' | 'average_service_duration_minutes' | 'active'>) => request<{ queue: Queue }>(`/queues/${id}/settings`, { method: 'PATCH', body: JSON.stringify({ queue: data }) }),
  report: async (id: number, period: 'daily' | 'weekly' | 'yearly') => {
    let response: Response;
    try { response = await fetch(`${base}/queues/${id}/reports?period=${period}`, { headers: { Authorization: `Bearer ${localStorage.getItem(sessionKey) || ''}` } }); }
    catch { throw new Error('Could not reach QueueLess. Check that the API is running and try again.'); }
    if (!response.ok) { const body = await response.json().catch(() => ({})) as ApiError; throw new Error(body.error?.message || `Report failed (${response.status})`); }
    return response.blob();
  },
};
