require 'rails_helper'
RSpec.describe QueueTokens::Register do
  it 'allocates sequential opaque tokens for a queue and date' do
    queue = create(:queue)
    one = described_class.new(queue: queue, attributes: { customer_name: 'Jordan Lee', service_type: 'Consultation' }).call
    two = described_class.new(queue: queue, attributes: { customer_name: 'Riley Chen', service_type: 'Consultation' }).call
    expect([one.token_number, two.token_number]).to eq(%w[G001 G002])
    expect(one.public_lookup_token).not_to eq(two.public_lookup_token)
    expect(one.public_lookup_token.length).to be >= 40
  end
end
RSpec.describe QueueTokens::Estimate do
  it 'counts each eligible customer ahead, including the active service' do
    queue = create(:queue, average_service_duration_minutes: 12)
    create(:queue_token, queue: queue, sequence_number: 1, token_number: 'A001', status: 'serving')
    waiting = create(:queue_token, queue: queue, sequence_number: 2, token_number: 'A002')
    estimate = described_class.new(waiting).call
    expect(estimate).to include(people_ahead: 1, estimated_wait_minutes: 12, queue_position: 2)
  end
  it 'excludes cancelled customers from queue position' do
    queue = create(:queue)
    create(:queue_token, queue: queue, sequence_number: 1, status: 'cancelled')
    waiting = create(:queue_token, queue: queue, sequence_number: 2)
    expect(described_class.new(waiting).call[:estimated_wait_minutes]).to eq(0)
  end
end
RSpec.describe ServiceQueue do
  it 'uses completed service history when available and the configured value otherwise' do
    queue = create(:queue, average_service_duration_minutes: 12)
    expect(queue.service_average).to eq(12)
    create(:queue_token, queue: queue, status: 'completed', service_started_at: 10.minutes.ago, completed_at: nil)
    expect(queue.service_average).to eq(12)
    create(:queue_token, queue: queue, status: 'completed', service_started_at: 10.minutes.ago, completed_at: Time.current)
    expect(queue.service_average).to eq(10)
  end

  it 'ignores near-instant accidental completions when estimating service duration' do
    queue = create(:queue, average_service_duration_minutes: 12)
    create(:queue_token, queue: queue, status: 'completed', service_started_at: 30.seconds.ago, completed_at: Time.current)
    create(:queue_token, queue: queue, status: 'completed', service_started_at: 10.minutes.ago, completed_at: Time.current)
    expect(queue.service_average).to eq(10)
  end
end
RSpec.describe QueueTokens::Lifecycle do
  it 'prevents another customer being called while one is serving' do
    queue = create(:queue)
    create(:queue_token, queue: queue, sequence_number: 1, status: 'serving')
    waiting = create(:queue_token, queue: queue, sequence_number: 2)
    expect { described_class.new(token: waiting, action: :call_next).call }.to raise_error(QueueTokens::Conflict)
  end
  it 'completes serving visits and rejects invalid transitions' do
    token = create(:queue_token, status: 'waiting')
    expect { described_class.new(token: token, action: :complete).call }.to raise_error(QueueTokens::Conflict)
    token.update!(status: 'serving')
    described_class.new(token: token, action: :complete).call
    expect(token.reload.status).to eq('completed')
  end
  it 'skips a serving visit and returns it to the end of the waiting line' do
    queue = create(:queue)
    first = create(:queue_token, queue: queue, sequence_number: 1, status: 'serving')
    second = create(:queue_token, queue: queue, sequence_number: 2, status: 'waiting')
    described_class.new(token: first, action: :skip).call
    described_class.new(token: first, action: :return_to_waiting).call
    expect(QueueTokens::Estimate.new(second.reload).call[:queue_position]).to eq(1)
    expect(QueueTokens::Estimate.new(first.reload).call[:queue_position]).to eq(2)
  end
end
