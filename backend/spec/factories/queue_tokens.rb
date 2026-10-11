FactoryBot.define do
  factory :queue_token do
    association :queue
    sequence(:sequence_number) { |n| n }
    sequence(:token_number) { |n| "A#{format('%03d', n)}" }
    sequence(:public_lookup_token) { |n| "opaque-token-#{n}" }
    service_date { Date.current.iso8601 }
    customer_name { 'Jordan Lee' }
    service_type { 'Consultation' }
    status { 'waiting' }
    joined_at { Time.current }
  end
end
