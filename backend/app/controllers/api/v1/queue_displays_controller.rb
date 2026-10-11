module Api::V1
  class QueueDisplaysController < ApplicationController
    skip_before_action :authenticate_staff!

    def show
      queue = ServiceQueue.active.find(params[:queue_id])
      today = queue.queue_tokens.for_today
      serving = today.find_by(status: 'serving')
      waiting = today.where(status: 'waiting').in_order.limit(6)

      render json: {
        queue_name: queue.name,
        service_type: queue.service_type,
        current_token: serving&.token_number,
        current_started_at: serving&.service_started_at,
        waiting_count: today.where(status: 'waiting').count,
        upcoming: waiting.map.with_index do |token, index|
          estimate = QueueTokens::Estimate.new(token).call
          {
            token_number: token.token_number,
            position: index + 1,
            status: index.zero? ? 'next' : 'waiting',
            estimated_wait_minutes: estimate[:estimated_wait_minutes],
            estimated_service_at: estimate[:estimated_service_at]
          }
        end,
        updated_at: Time.current
      }
    end
  end
end
