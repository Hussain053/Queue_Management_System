class StaffUser < ApplicationRecord
  has_secure_password
  has_many :staff_sessions, dependent: :delete_all
  ROLES = %w[admin doctor receptionist].freeze

  validates :username, :display_name, presence: true
  validates :username, uniqueness: { case_sensitive: false }
  validates :role, inclusion: { in: ROLES }

  def as_json(options = {})
    super(options.merge(only: %i[id username display_name role]))
  end
end
