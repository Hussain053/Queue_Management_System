require 'digest'
require 'securerandom'

module Api::V1
  class AuthController < ApplicationController
    skip_before_action :authenticate_staff!, only: :create

    def create
      username = params[:username].to_s.downcase
      username = 'receptionist' if username == 'receptionlist'
      user = StaffUser.where('LOWER(username) = ?', username).find_by(active: true)
      unless user&.authenticate(params[:password].to_s)
        render json: { error: { code: 'invalid_credentials', message: 'Username or password is incorrect.' } }, status: :unauthorized
        return
      end
      raw_token = SecureRandom.urlsafe_base64(48)
      user.staff_sessions.create!(token_digest: Digest::SHA256.hexdigest(raw_token), expires_at: 30.days.from_now)
      user.update_column(:last_login_at, Time.current)
      render json: { token: raw_token, user: user }
    end

    def show
      render json: { user: current_staff_user }
    end

    def destroy
      raw_token = request.headers['Authorization'].to_s[/\ABearer\s+(.+)\z/i, 1]
      StaffSession.find_by(token_digest: Digest::SHA256.hexdigest(raw_token.to_s))&.destroy!
      head :no_content
    end
  end
end
