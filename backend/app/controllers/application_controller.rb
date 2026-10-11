require 'digest'

class ApplicationController < ActionController::API
  before_action :authenticate_staff!
  rescue_from StandardError do |error|
    raise error unless Rails.env.production?
    Rails.logger.error("QueueLess API error: #{error.class}: #{error.message}")
    render json: { error: { code: 'internal_error', message: 'An unexpected error occurred.' } }, status: :internal_server_error
  end
  rescue_from ActiveRecord::RecordNotFound do
    render json: { error: { code: 'not_found', message: 'The requested resource was not found.' } }, status: :not_found
  end
  rescue_from ActiveRecord::RecordInvalid do |error|
    render json: { error: { code: 'validation_error', message: error.record.errors.full_messages.to_sentence, details: error.record.errors.to_hash } }, status: :unprocessable_entity
  end
  rescue_from QueueTokens::Conflict do |error|
    render json: { error: { code: 'conflict', message: error.message } }, status: :conflict
  end
  rescue_from ActionController::ParameterMissing do |error|
    render json: { error: { code: 'validation_error', message: error.message } }, status: :unprocessable_entity
  end
  rescue_from ActiveRecord::RecordNotUnique do
    render json: { error: { code: 'conflict', message: 'That token could not be allocated. Please retry.' } }, status: :conflict
  end
  private
  attr_reader :current_staff_user, :current_staff_session

  def authenticate_staff!
    raw_token = request.headers['Authorization'].to_s[/\ABearer\s+(.+)\z/i, 1]
    session = raw_token && StaffSession.includes(:staff_user).find_by(token_digest: Digest::SHA256.hexdigest(raw_token))
    @current_staff_session = session if session && session.expires_at.future?
    @current_staff_user = current_staff_session&.staff_user
    return if @current_staff_user&.active?

    render json: { error: { code: 'unauthorized', message: 'Sign in to continue.' } }, status: :unauthorized
  end

  def require_staff_role!(*roles)
    return true if current_staff_user&.role.in?(roles)

    render json: { error: { code: 'forbidden', message: 'Your account does not have permission for this action.' } }, status: :forbidden
    false
  end

  def token_json(token, include_private: true)
    estimate = QueueTokens::Estimate.new(token).call
    json = { id: token.id, token_number: token.token_number, customer_name: token.customer_name,
      service_type: token.service_type, visit_requirements: token.visit_requirements, status: token.status, joined_at: token.joined_at, service_started_at: token.service_started_at,
      queue_position: estimate[:queue_position], estimated_wait_minutes: estimate[:estimated_wait_minutes], estimated_service_at: estimate[:estimated_service_at] }
    json.merge!(contact_number: token.contact_number) if include_private && current_staff_user&.role != 'doctor'
    json[:note] = token.note if include_private && current_staff_user&.role != 'doctor'
    json
  end
end
