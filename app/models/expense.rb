class Expense < ApplicationRecord
  has_one_attached :receipt

  belongs_to :user
  belongs_to :category
  belongs_to :household, optional: true

  validates :description, :date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
end
