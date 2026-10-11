FactoryBot.define do
  factory :staff_user do
    sequence(:username) { |n| "staff#{n}" }
    display_name { 'Taylor Staff' }
    role { 'admin' }
    password { 'test-password' }
    active { true }
  end
end
