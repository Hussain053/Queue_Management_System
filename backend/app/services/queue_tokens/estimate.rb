module QueueTokens
  # A serving visit occupies one service duration; waiting tokens ahead are counted in FIFO order.
  class Estimate
    def initialize(token)
      @token = token
    end
    def call
      return { people_ahead: 0, estimated_wait_minutes: 0, estimated_service_at: nil, queue_position: nil } unless %w[waiting serving].include?(@token.status)
      active = @token.queue.queue_tokens.for_today.where(status: %w[waiting serving]).in_order.to_a
      index = active.index(@token)
      return { people_ahead: 0, estimated_wait_minutes: 0, estimated_service_at: nil, queue_position: nil } unless index
      ahead = index
      average = @token.queue.service_average
      wait = if @token.status == 'serving'
        0
      else
        active.take(index).sum do |token|
          if token.status == 'serving' && token.service_started_at
            [(average - ((Time.current - token.service_started_at) / 60.0)).ceil, 0].max
          else
            average
          end
        end
      end
      { people_ahead: ahead, estimated_wait_minutes: wait, estimated_service_at: Time.current + wait.minutes, queue_position: index + 1 }
    end
  end
end
