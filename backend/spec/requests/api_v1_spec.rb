require 'rails_helper'
RSpec.describe 'QueueLess API', type: :request do
  def auth_headers(username: 'admin', password: 'admin')
    StaffUser.find_or_create_by!(username: username) do |user|
      user.display_name = username == 'doctor' ? 'Dr. Test' : 'Queue Admin'
      user.role = username == 'doctor' ? 'doctor' : 'admin'
      user.password = password
    end
    post '/api/v1/auth/login', params: { username: username, password: password }, as: :json
    { 'Authorization' => "Bearer #{response.parsed_body.fetch('token')}" }
  end

  it 'creates a customer token and only exposes safe fields from public lookup' do
    queue = create(:queue)
    headers = auth_headers
    post "/api/v1/queues/#{queue.id}/tokens", params: { queue_token: { customer_name: 'Jordan Lee', service_type: 'Consultation', contact_number: '555-0102', visit_requirements: 'Mobility assistance', note: 'Private note' } }, headers: headers, as: :json
    expect(response).to have_http_status(:created)
    lookup = response.parsed_body.fetch('public_lookup_token')
    get "/api/v1/tokens/#{lookup}"
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.keys).not_to include('id', 'contact_number', 'note', 'customer_name', 'visit_requirements')
  end
  it 'returns 404 for a missing public lookup' do
    get '/api/v1/tokens/unknown-lookup'
    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body.dig('error', 'code')).to eq('not_found')
  end

  it 'shows a public queue display with token numbers but no patient details' do
    queue = create(:queue)
    create(:queue_token, queue: queue, sequence_number: 1, token_number: 'G001', status: 'serving', service_started_at: 4.minutes.ago, customer_name: 'Kavya Reddy', contact_number: '9876543210', visit_requirements: 'Private requirement', note: 'Private note')
    create(:queue_token, queue: queue, sequence_number: 2, token_number: 'G002', status: 'waiting', customer_name: 'Arjun Mehta', contact_number: '9876543211', visit_requirements: 'Private requirement', note: 'Private note')

    get "/api/v1/display/#{queue.id}"

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include('current_token' => 'G001', 'waiting_count' => 1)
    expect(response.parsed_body.fetch('upcoming').first).to include('token_number' => 'G002', 'status' => 'next')
    expect(response.body).not_to include('Kavya Reddy', 'Arjun Mehta', '9876543210', 'Private requirement', 'Private note')
  end
  it 'returns validation errors for a missing customer name' do
    queue = create(:queue)
    post "/api/v1/queues/#{queue.id}/tokens", params: { queue_token: { customer_name: '', service_type: 'Consultation' } }, headers: auth_headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.dig('error', 'code')).to eq('validation_error')
  end
  it 'calls the first waiting customer and reports an empty queue conflict' do
    queue = create(:queue)
    headers = auth_headers
    post "/api/v1/queues/#{queue.id}/call_next", headers: headers, as: :json
    expect(response).to have_http_status(:conflict)
    token = create(:queue_token, queue: queue)
    post "/api/v1/queues/#{queue.id}/call_next", headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('token', 'id')).to eq(token.id)
    expect(token.reload.status).to eq('serving')
  end

  it 'protects staff APIs and grants the doctor a requirements-only patient summary' do
    queue = create(:queue)
    receptionist_headers = auth_headers
    post "/api/v1/queues/#{queue.id}/tokens", params: { queue_token: { customer_name: 'Jordan Lee', service_type: 'Consultation', contact_number: '555-0102', visit_requirements: 'Wheelchair access', note: 'Staff-only billing detail' } }, headers: receptionist_headers, as: :json
    expect(response).to have_http_status(:created)
    doctor = create(:staff_user, username: 'doctor', role: 'doctor', password: '1234')
    doctor_headers = auth_headers(username: doctor.username, password: '1234')
    get "/api/v1/queues/#{queue.id}/dashboard", headers: doctor_headers
    patient = response.parsed_body.fetch('next_waiting_token')
    expect(patient['visit_requirements']).to eq('Wheelchair access')
    expect(patient.keys).not_to include('contact_number', 'note')
    post "/api/v1/queues/#{queue.id}/call_next", headers: doctor_headers, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it 'supports admin settings and CSV reports' do
    queue = create(:queue)
    headers = auth_headers
    patch "/api/v1/queues/#{queue.id}/settings", params: { queue: { average_service_duration_minutes: 15 } }, headers: headers, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('queue', 'average_service_duration_minutes')).to eq(15)
    get "/api/v1/queues/#{queue.id}/reports", params: { period: 'yearly' }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq('text/csv')
    expect(response.body).to include('period,start_date,end_date,token_number,customer_name')
  end

  it 'rejects bad credentials and requires authentication for staff routes' do
    create(:staff_user, username: 'admin', password: 'admin')
    post '/api/v1/auth/login', params: { username: 'admin', password: 'wrong' }, as: :json
    expect(response).to have_http_status(:unauthorized)
    get '/api/v1/queues'
    expect(response).to have_http_status(:unauthorized)
  end

  it 'accepts receptionlist as a sign-in alias for the receptionist role' do
    create(:staff_user, username: 'receptionist', role: 'receptionist', password: '1234')
    post '/api/v1/auth/login', params: { username: 'receptionlist', password: '1234' }, as: :json
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('user', 'role')).to eq('receptionist')
  end
end
