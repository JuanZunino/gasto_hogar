class Household < ApplicationRecord
  has_many :expenses, dependent: :restrict_with_error
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates :name, presence: true
end
