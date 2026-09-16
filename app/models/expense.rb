class Expense < ApplicationRecord
  belongs_to :user
  belongs_to :category
  belongs_to :household, optional: true

  validates :description, :date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
end
