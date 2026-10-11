export type TokenStatus = 'waiting' | 'serving' | 'completed' | 'skipped' | 'cancelled';
export interface Queue { id: number; name: string; service_type: string; average_service_duration_minutes: number; active: boolean }
export interface QueueToken { id: number; token_number: string; customer_name: string; service_type: string; visit_requirements?: string | null; status: TokenStatus; joined_at: string; service_started_at?: string | null; estimated_service_at?: string | null; queue_position: number | null; estimated_wait_minutes: number; contact_number?: string | null; note?: string | null }
export interface Dashboard { tokens_issued_today: number; waiting_customers: number; serving_customers: number; completed_services: number; average_service_duration_minutes: number; current_serving_token: QueueToken | null; next_waiting_token: QueueToken | null; recent_activity: QueueToken[] }
export interface PublicToken extends Omit<QueueToken, 'id' | 'customer_name' | 'contact_number' | 'note' | 'visit_requirements'> { people_ahead: number; current_serving_token: string | null }
export interface QueueDisplayEntry { token_number: string; position: number; status: 'next' | 'waiting'; estimated_wait_minutes: number; estimated_service_at: string | null }
export interface QueueDisplay { queue_name: string; service_type: string; current_token: string | null; current_started_at: string | null; waiting_count: number; upcoming: QueueDisplayEntry[]; updated_at: string }
export interface ApiError { error: { code: string; message: string; details?: Record<string, string[]> } }
export interface StaffUser { id: number; username: string; display_name: string; role: 'admin' | 'doctor' | 'receptionist' }
