class Expense < ApplicationRecord
  has_one_attached :receipt

  belongs_to :user
  belongs_to :category
  belongs_to :household, optional: true

  validates :description, :date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validate :category_is_available_to_user

  private

  def category_is_available_to_user
    return unless category && user
    return if category.user_id.nil? || category.user_id == user_id

    errors.add(:category, "debe ser global o pertenecer al usuario del gasto")
  end
end
