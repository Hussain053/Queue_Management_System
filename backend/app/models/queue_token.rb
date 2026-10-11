class QueueToken < ApplicationRecord
  STATUSES = %w[waiting serving completed skipped cancelled].freeze
  belongs_to :queue, class_name: 'ServiceQueue'
  validates :customer_name, presence: true, length: { minimum: 2, maximum: 120 }
  validates :service_type, presence: true, length: { maximum: 100 }
  validates :visit_requirements, length: { maximum: 2000 }, allow_nil: true
  validates :token_number, :public_lookup_token, :service_date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 }
  scope :for_today, -> { where(service_date: Date.current.iso8601) }
  scope :active_in_line, -> { where(status: %w[waiting serving]) }
  # joined_at moves returned skipped visits to the end; sequence breaks timestamp ties.
  scope :in_order, -> { order(:joined_at, :sequence_number) }
end
