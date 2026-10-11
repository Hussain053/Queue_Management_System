require 'rails_helper'
RSpec.describe QueueToken, type: :model do
  it 'requires a customer name, service, and valid status' do
    token = build(:queue_token, customer_name: '', service_type: '', status: 'unknown')
    expect(token).not_to be_valid
    expect(token.errors.attribute_names).to include(:customer_name, :service_type, :status)
  end
  it 'enforces unique daily sequence in the database' do
    first = create(:queue_token, sequence_number: 1)
    duplicate = build(:queue_token, queue: first.queue, sequence_number: 1, token_number: 'A999')
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
