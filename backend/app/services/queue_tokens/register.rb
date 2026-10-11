require 'securerandom'
module QueueTokens
  # Queue row lock serializes daily sequence allocation and queue lifecycle writes.
  class Register
    def initialize(queue:, attributes:)
      @queue, @attributes = queue, attributes
    end
    def call
      token = nil
      @queue.with_lock do
        date = Date.current.iso8601
        sequence = @queue.queue_tokens.where(service_date: date).maximum(:sequence_number).to_i + 1
        token = @queue.queue_tokens.create!(@attributes.merge(service_date: date, sequence_number: sequence,
          token_number: format('%s%03d', @queue.name.first.upcase, sequence),
          public_lookup_token: SecureRandom.urlsafe_base64(32), status: 'waiting', joined_at: Time.current))
      end
      token
    end
  end
end
