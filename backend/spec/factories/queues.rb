FactoryBot.define do
  factory :queue, class: 'ServiceQueue' do
    name { 'General Consultation' }
    service_type { 'Consultation' }
    average_service_duration_minutes { 12 }
    active { true }
  end
end
