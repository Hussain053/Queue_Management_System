module Api::V1
  class TokensController < ApplicationController
    def create
      return unless require_staff_role!('admin', 'receptionist')
      queue = ServiceQueue.active.find(params[:queue_id])
      token = QueueTokens::Register.new(queue: queue, attributes: token_params.to_h).call
      render json: { token: token_json(token), public_lookup_token: token.public_lookup_token }, status: :created
    end
    private
    def token_params
      params.require(:queue_token).permit(:customer_name, :contact_number, :service_type, :visit_requirements, :note)
    end
  end
end
