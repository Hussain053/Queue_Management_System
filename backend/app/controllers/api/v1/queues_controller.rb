require 'csv'

module Api::V1
  class QueuesController < ApplicationController
    before_action :set_queue, only: %i[show dashboard tokens call_next settings reports]
    def index
      queues = if current_staff_user.role == 'admin' && ActiveModel::Type::Boolean.new.cast(params[:include_inactive])
        ServiceQueue.order(:id)
      else
        ServiceQueue.active.order(:id)
      end
      render json: { queues: queues.map { |q| queue_json(q) } }
    end
    def show
      render json: { queue: queue_json(@queue) }
    end
    def tokens
      rows = @queue.queue_tokens.for_today.in_order.map { |t| token_json(t) }
      render json: { tokens: rows }
    end
    def dashboard
      today = @queue.queue_tokens.for_today
      serving = today.find_by(status: 'serving')
      next_waiting = today.where(status: 'waiting').in_order.first
      render json: { tokens_issued_today: today.count, waiting_customers: today.where(status: 'waiting').count,
        serving_customers: today.where(status: 'serving').count, completed_services: today.where(status: 'completed').count,
        average_service_duration_minutes: @queue.service_average, current_serving_token: serving && token_json(serving),
        next_waiting_token: next_waiting && token_json(next_waiting),
        recent_activity: today.order(updated_at: :desc).limit(6).map { |t| token_json(t) } }
    end
    def call_next
      return unless require_staff_role!('admin', 'receptionist')
      token = @queue.queue_tokens.for_today.where(status: 'waiting').in_order.first
      raise QueueTokens::Conflict, 'There are no waiting customers.' unless token
      QueueTokens::Lifecycle.new(token: token, action: :call_next).call
      render json: { token: token_json(token) }
    end
    def settings
      return unless require_staff_role!('admin')
      @queue.update!(settings_params)
      render json: { queue: queue_json(@queue) }
    end
    def reports
      return unless require_staff_role!('admin')
      period = params[:period].presence || 'daily'
      start_date, end_date = case period
      when 'daily' then [Date.current, Date.current]
      when 'weekly' then [Date.current.beginning_of_week, Date.current.end_of_week]
      when 'yearly' then [Date.current.beginning_of_year, Date.current.end_of_year]
      else
        render json: { error: { code: 'validation_error', message: 'Period must be daily, weekly, or yearly.' } }, status: :unprocessable_entity
        return
      end
      tokens = @queue.queue_tokens.where(service_date: start_date.iso8601..end_date.iso8601).order(:service_date, :sequence_number)
      csv = CSV.generate(headers: true) do |out|
        out << %w[period start_date end_date token_number customer_name service_type status joined_at service_started_at completed_at service_minutes requirements staff_note]
        tokens.each do |token|
          minutes = token.service_started_at && token.completed_at ? ((token.completed_at - token.service_started_at) / 60).round : nil
          out << [period, start_date, end_date, token.token_number, token.customer_name, token.service_type, token.status,
            token.joined_at, token.service_started_at, token.completed_at, minutes, token.visit_requirements, token.note]
        end
      end
      send_data csv, filename: "queueless-#{@queue.id}-#{period}-#{Date.current.iso8601}.csv", type: 'text/csv; charset=utf-8'
    end
    private
    def set_queue
      @queue = ServiceQueue.find(params[:id])
    end
    def queue_json(queue)
      { id: queue.id, name: queue.name, service_type: queue.service_type,
        average_service_duration_minutes: queue.average_service_duration_minutes, active: queue.active }
    end
    def settings_params
      params.require(:queue).permit(:name, :service_type, :average_service_duration_minutes, :active)
    end
  end
end
