class StaffSession < ApplicationRecord
  belongs_to :staff_user
  validates :token_digest, :expires_at, presence: true
end
