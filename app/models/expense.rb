class Expense < ApplicationRecord
  has_one_attached :receipt

  belongs_to :user
  belongs_to :category
  belongs_to :household, optional: true

  scope :visible_to, ->(user) {
    where(user_id: user.id, household_id: nil)
      .or(where(household_id: user.memberships.select(:household_id)))
  }

  validates :description, :date, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :amount, numericality: {
    less_than_or_equal_to: BigDecimal("9999999999.99"),
    message: "no puede superar $9.999.999.999,99"
  }, allow_blank: true
  validate :category_is_available_to_user

  private

  def category_is_available_to_user
    return unless category && user
    return if category.user_id.nil? || category.user_id == user_id

    errors.add(:category, "debe ser global o pertenecer al usuario del gasto")
  end
end
