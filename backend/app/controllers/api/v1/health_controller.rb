module Api::V1
  class HealthController < ApplicationController
    skip_before_action :authenticate_staff!
    def show
      ActiveRecord::Base.connection.execute('SELECT 1')
      render json: { status: 'ok', database: 'connected' }
    end
  end
end
