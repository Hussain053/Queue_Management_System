general = ServiceQueue.find_or_create_by!(name: 'General Consultation') do |queue|
  queue.service_type = 'Consultation'
  queue.average_service_duration_minutes = 12
end

follow_up = ServiceQueue.find_or_create_by!(name: 'Follow-up') do |queue|
  queue.service_type = 'Follow-up'
  queue.average_service_duration_minutes = 8
end

def seed_staff_account(username:, display_name:, role:, password:)
  user = StaffUser.find_or_initialize_by(username: username)
  user.assign_attributes(display_name: display_name, role: role, password: password, active: true)
  user.save!
end

if Rails.env.production?
  admin_username = ENV['QUEUELESS_ADMIN_USERNAME'].to_s.strip
  admin_password = ENV['QUEUELESS_ADMIN_PASSWORD'].to_s
  if admin_username.blank? || admin_password.length < 12
    raise 'Set QUEUELESS_ADMIN_USERNAME and a QUEUELESS_ADMIN_PASSWORD of at least 12 characters before running production seeds.'
  end

  seed_staff_account(
    username: admin_username,
    display_name: ENV.fetch('QUEUELESS_ADMIN_NAME', 'Clinic Administrator'),
    role: 'admin',
    password: admin_password
  )

  {
    doctor: ['QUEUELESS_DOCTOR_USERNAME', 'QUEUELESS_DOCTOR_PASSWORD', 'QUEUELESS_DOCTOR_NAME', 'Dr. Clinic Staff'],
    receptionist: ['QUEUELESS_RECEPTIONIST_USERNAME', 'QUEUELESS_RECEPTIONIST_PASSWORD', 'QUEUELESS_RECEPTIONIST_NAME', 'Clinic Reception']
  }.each do |role, (username_key, password_key, name_key, default_name)|
    username = ENV[username_key].to_s.strip
    password = ENV[password_key].to_s
    next if username.blank? && password.blank?
    raise "Set both #{username_key} and #{password_key}; passwords must contain at least 12 characters." if username.blank? || password.length < 12

    seed_staff_account(username: username, display_name: ENV.fetch(name_key, default_name), role: role.to_s, password: password)
  end

  puts 'Production queues and configured staff accounts are ready. No sample patient visits were created.'
elsif Rails.env.development?
  [
    { username: 'admin', display_name: 'Queue Admin', role: 'admin', password: 'admin' },
    { username: 'doctor', display_name: 'Dr. Maya Patel', role: 'doctor', password: '1234' },
    { username: 'receptionist', display_name: 'Front Desk', role: 'receptionist', password: '1234' }
  ].each { |account| seed_staff_account(**account) }

  marker = 'DEMO SAMPLE - fictional visit'
  now = Time.current
  today = Date.current.iso8601

  seed_visit = lambda do |queue, attributes|
    next if queue.queue_tokens.exists?(service_date: today, customer_name: attributes.fetch(:name), note: marker)

    token = QueueTokens::Register.new(queue: queue, attributes: {
      customer_name: attributes.fetch(:name),
      service_type: attributes.fetch(:service),
      visit_requirements: attributes[:requirements],
      note: marker
    }).call

    joined_at = now - attributes.fetch(:joined_minutes_ago).minutes
    started_at = attributes[:started_minutes_ago] && now - attributes[:started_minutes_ago].minutes
    completed_at = started_at && started_at + attributes.fetch(:service_minutes).minutes
    token.update_columns(
      joined_at: joined_at,
      status: attributes.fetch(:status),
      called_at: started_at,
      service_started_at: started_at,
      completed_at: completed_at,
      updated_at: now
    )
  end

  [
    { name: 'Aarav Sharma', service: 'Consultation', status: 'completed', joined_minutes_ago: 155, started_minutes_ago: 150, service_minutes: 12, requirements: 'Routine consultation' },
    { name: 'Priya Nair', service: 'Consultation', status: 'completed', joined_minutes_ago: 125, started_minutes_ago: 120, service_minutes: 11, requirements: 'Follow-up visit' },
    { name: 'Rohan Kulkarni', service: 'Consultation', status: 'completed', joined_minutes_ago: 96, started_minutes_ago: 91, service_minutes: 13, requirements: 'Review recent test results' },
    { name: 'Meera Iyer', service: 'Consultation', status: 'completed', joined_minutes_ago: 68, started_minutes_ago: 64, service_minutes: 10, requirements: 'Routine consultation' },
    { name: 'Kavya Reddy', service: 'Consultation', status: 'serving', joined_minutes_ago: 18, started_minutes_ago: 8, service_minutes: 12, requirements: 'Prefers Hindi' },
    { name: 'Arjun Mehta', service: 'Consultation', status: 'waiting', joined_minutes_ago: 7, requirements: 'Follow-up: medication review' },
    { name: 'Sana Khan', service: 'Consultation', status: 'waiting', joined_minutes_ago: 5, requirements: 'Needs step-free access' },
    { name: 'Dev Patel', service: 'Consultation', status: 'waiting', joined_minutes_ago: 3, requirements: 'Routine consultation' },
    { name: 'Nisha Joshi', service: 'Consultation', status: 'waiting', joined_minutes_ago: 1, requirements: 'First visit' }
  ].each { |visit| seed_visit.call(general, visit) }

  [
    { name: 'Ishita Desai', service: 'Follow-up', status: 'completed', joined_minutes_ago: 105, started_minutes_ago: 100, service_minutes: 9, requirements: 'Follow-up visit' },
    { name: 'Vikram Rao', service: 'Follow-up', status: 'completed', joined_minutes_ago: 76, started_minutes_ago: 72, service_minutes: 8, requirements: 'Review recent test results' },
    { name: 'Ananya Bose', service: 'Follow-up', status: 'waiting', joined_minutes_ago: 12, requirements: 'Medication review' },
    { name: 'Kabir Shah', service: 'Follow-up', status: 'waiting', joined_minutes_ago: 6, requirements: 'Follow-up visit' }
  ].each { |visit| seed_visit.call(follow_up, visit) }

  puts 'Development queues, demo staff, and fictional Indian-name sample visits are ready.'
else
  puts "QueueLess queues are ready. No demo users or sample visits were added in #{Rails.env}."
end
