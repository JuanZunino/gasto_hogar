class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :household

  validates :role, presence: true, inclusion: { in: %w[owner member] }
  validates :user_id, uniqueness: { scope: :household_id }
end
