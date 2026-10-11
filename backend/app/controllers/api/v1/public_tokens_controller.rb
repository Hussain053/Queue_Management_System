module Api::V1
  class PublicTokensController < ApplicationController
    skip_before_action :authenticate_staff!
    def show
      token = QueueToken.includes(:queue).find_by!(public_lookup_token: params[:public_lookup_token])
      estimate = QueueTokens::Estimate.new(token).call
      serving = token.queue.queue_tokens.for_today.find_by(status: 'serving')
      render json: { token_number: token.token_number, service_type: token.service_type, status: token.status,
        people_ahead: estimate[:people_ahead], estimated_wait_minutes: estimate[:estimated_wait_minutes], estimated_service_at: estimate[:estimated_service_at],
        current_serving_token: serving&.token_number }
    end
  end
end
