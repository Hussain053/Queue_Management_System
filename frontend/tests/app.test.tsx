import { beforeEach, describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import App from '../src/App';
import { api } from '../src/services/api/client';

const admin = { id: 1, username: 'admin', display_name: 'Queue Admin', role: 'admin' as const };
const doctor = { id: 2, username: 'doctor', display_name: 'Dr. Maya Patel', role: 'doctor' as const };
vi.mock('../src/services/api/client', () => ({ api: {
  hasSession: vi.fn(() => true), me: vi.fn().mockResolvedValue({ user: { id: 1, username: 'admin', display_name: 'Queue Admin', role: 'admin' } }),
  login: vi.fn().mockResolvedValue({ id: 1, username: 'admin', display_name: 'Queue Admin', role: 'admin' }), logout: vi.fn(),
  queues: vi.fn().mockResolvedValue({ queues: [{ id: 1, name: 'General Consultation', service_type: 'Consultation', average_service_duration_minutes: 12, active: true }] }),
  dashboard: vi.fn().mockResolvedValue({ tokens_issued_today: 8, waiting_customers: 3, serving_customers: 1, completed_services: 4, average_service_duration_minutes: 11, current_serving_token: null, next_waiting_token: null, recent_activity: [] }),
  tokens: vi.fn().mockResolvedValue({ tokens: [] }), publicToken: vi.fn().mockResolvedValue({ token_number: 'A008', status: 'waiting', people_ahead: 2, estimated_wait_minutes: 24, current_serving_token: 'A005' }),
  queueDisplay: vi.fn().mockResolvedValue({ queue_name: 'General Consultation', service_type: 'Consultation', current_token: 'G005', current_started_at: new Date().toISOString(), waiting_count: 2, upcoming: [{ token_number: 'G006', position: 1, status: 'next', estimated_wait_minutes: 12, estimated_service_at: new Date().toISOString() }, { token_number: 'G007', position: 2, status: 'waiting', estimated_wait_minutes: 24, estimated_service_at: new Date().toISOString() }], updated_at: new Date().toISOString() }),
  createToken: vi.fn().mockResolvedValue({ token: { id: 9, token_number: 'G009', customer_name: 'Taylor Smith', service_type: 'Consultation', status: 'waiting', joined_at: new Date().toISOString(), queue_position: 3, estimated_wait_minutes: 24 }, public_lookup_token: 'random-private-lookup' }),
  updateQueue: vi.fn().mockResolvedValue({ queue: {} }), report: vi.fn().mockResolvedValue(new Blob(['report'])), action: vi.fn(), callNext: vi.fn(),
} }));

const renderApp = (path = '/') => render(<MemoryRouter initialEntries={[path]}><App /></MemoryRouter>);
beforeEach(() => { vi.clearAllMocks(); vi.mocked(api.hasSession).mockReturnValue(true); vi.mocked(api.me).mockResolvedValue({ user: admin }); });

describe('QueueLess views', () => {
  it('renders dashboard statistics from the backend', async () => {
    renderApp();
    expect(await screen.findByRole('heading', { name: /Good day, Queue/ })).toBeInTheDocument();
    expect(await screen.findByText('8')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Waiting room display' })).toHaveAttribute('href', '/display/1');
  });
  it('fills and signs in the receptionist demo account', async () => {
    vi.mocked(api.hasSession).mockReturnValue(false);
    vi.mocked(api.login).mockResolvedValueOnce({ id: 3, username: 'receptionist', display_name: 'Front Desk', role: 'receptionist' });
    const user = userEvent.setup(); renderApp();
    expect(screen.getByRole('link', { name: /public waiting room display/i })).toHaveAttribute('href', '/display/1');
    await user.click(screen.getByRole('button', { name: 'Receptionist - receptionist / 1234' }));
    await user.click(screen.getByRole('button', { name: 'Sign in' }));
    expect(await screen.findByRole('heading', { name: /Good day, Front/ })).toBeInTheDocument();
    expect(api.login).toHaveBeenCalledWith('receptionist', '1234');
  });
  it('registers a customer and shows their private token link', async () => {
    const user = userEvent.setup(); renderApp();
    await user.click(await screen.findByRole('button', { name: /New customer/ }));
    await user.type(screen.getByLabelText('Customer name'), 'Taylor Smith');
    await user.click(screen.getByRole('button', { name: /Create token/ }));
    expect(await screen.findByRole('heading', { name: 'Token created' })).toBeInTheDocument();
    expect(screen.getByText('G009')).toBeInTheDocument();
    expect(screen.getByDisplayValue(/random-private-lookup/)).toBeInTheDocument();
  });
  it('shows visit requirements to doctors without administrator controls', async () => {
    vi.mocked(api.me).mockResolvedValueOnce({ user: doctor });
    vi.mocked(api.tokens).mockResolvedValue({ tokens: [{ id: 12, token_number: 'A012', customer_name: 'Jordan Lee', service_type: 'Consultation', visit_requirements: 'Wheelchair access', status: 'waiting', joined_at: new Date().toISOString(), queue_position: 1, estimated_wait_minutes: 8 }] });
    renderApp();
    expect(await screen.findByText('Wheelchair access')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Settings' })).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: /Add customer|New customer/ })).not.toBeInTheDocument();
  });
  it('saves administrator queue settings', async () => {
    const user = userEvent.setup(); renderApp('/settings');
    await user.clear(await screen.findByRole('spinbutton'));
    await user.type(screen.getByRole('spinbutton'), '18');
    await user.click(screen.getByRole('button', { name: 'Save settings' }));
    await waitFor(() => expect(api.updateQueue).toHaveBeenCalledWith(1, expect.objectContaining({ average_service_duration_minutes: 18 })));
    expect(await screen.findByText('Queue settings saved.')).toBeInTheDocument();
  });
  it('shows a private token status without a customer identity', async () => {
    renderApp('/token/private');
    expect(await screen.findByText('A008')).toBeInTheDocument();
    expect(screen.getByText('People ahead')).toBeInTheDocument();
    expect(screen.getByText('waiting')).toBeInTheDocument();
    expect(screen.getByRole('link', { name: 'Open waiting room display' })).toHaveAttribute('href', '/display/1');
  });
  it('opens the public screen-only queue display without staff navigation', async () => {
    renderApp('/display/1');
    expect(await screen.findByText('G005')).toBeInTheDocument();
    expect(screen.getByText('G006')).toBeInTheDocument();
    expect(screen.getByText('NOW SERVING')).toBeInTheDocument();
    expect(screen.queryByRole('link', { name: 'Settings' })).not.toBeInTheDocument();
    expect(api.me).not.toHaveBeenCalled();
  });
  it('shows the first waiting token prominently while nobody is serving', async () => {
    vi.mocked(api.queueDisplay).mockResolvedValueOnce({ queue_name: 'General Consultation', service_type: 'Consultation', current_token: null, current_started_at: null, waiting_count: 1, upcoming: [{ token_number: 'G013', position: 1, status: 'next', estimated_wait_minutes: 0, estimated_service_at: new Date().toISOString() }], updated_at: new Date().toISOString() });
    renderApp('/display/1');
    expect((await screen.findAllByText('G013')).length).toBe(2);
    expect(screen.getByText('NEXT TO BE CALLED')).toBeInTheDocument();
    expect(screen.getByText('You are next in line. Please wait to be called.')).toBeInTheDocument();
  });
});
