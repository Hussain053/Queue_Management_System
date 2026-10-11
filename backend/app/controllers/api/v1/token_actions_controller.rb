module Api::V1
  class TokenActionsController < ApplicationController
    def update
      return unless require_staff_role!('admin', 'receptionist')
      token = QueueToken.find(params[:id])
      QueueTokens::Lifecycle.new(token: token, action: params[:operation]).call
      render json: { token: token_json(token) }
    end
  end
end
