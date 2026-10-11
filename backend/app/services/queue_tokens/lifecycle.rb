module QueueTokens
  class Lifecycle
    def initialize(token:, action:)
      @token, @action = token, action.to_s
    end
    def call
      @token.queue.with_lock do
        @token.reload
        case @action
        when 'call_next'
          raise Conflict, 'A customer is already being served.' if @token.queue.queue_tokens.for_today.exists?(status: 'serving')
          raise Conflict, 'Only the first waiting customer can be called.' unless @token.status == 'waiting' && @token.queue.queue_tokens.for_today.where(status: 'waiting').in_order.first == @token
          @token.update!(status: 'serving', called_at: Time.current, service_started_at: Time.current)
        when 'complete'
          require_status!('serving'); @token.update!(status: 'completed', completed_at: Time.current)
        when 'skip'
          require_status!('serving'); @token.update!(status: 'skipped', completed_at: Time.current)
        when 'return_to_waiting'
          require_status!('skipped'); @token.update!(status: 'waiting', completed_at: nil, called_at: nil, service_started_at: nil, joined_at: Time.current)
        when 'cancel'
          require_status!('waiting'); @token.update!(status: 'cancelled')
        else
          raise Conflict, 'Unsupported queue action.'
        end
      end
      @token
    end
    private
    def require_status!(expected)
      raise Conflict, "Cannot #{@action} a token with status #{@token.status}." unless @token.status == expected
    end
  end
end
