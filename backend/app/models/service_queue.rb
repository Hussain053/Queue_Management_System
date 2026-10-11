class ServiceQueue < ApplicationRecord
  self.table_name = 'queues'
  has_many :queue_tokens, class_name: 'QueueToken', foreign_key: :queue_id, dependent: :restrict_with_exception
  validates :name, :service_type, presence: true
  validates :average_service_duration_minutes, numericality: { only_integer: true, greater_than: 0 }
  scope :active, -> { where(active: true) }

  def service_average
    durations = queue_tokens.where(status: 'completed').where.not(service_started_at: nil).where.not(completed_at: nil)
      .where(service_date: Date.current.iso8601)
      .where("completed_at - service_started_at >= INTERVAL '2 minutes'")
    return average_service_duration_minutes if durations.empty?
    [(durations.sum('EXTRACT(EPOCH FROM (completed_at - service_started_at))') / durations.count / 60.0).round, 1].max
  end
end
