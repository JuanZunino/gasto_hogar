class Category < ApplicationRecord
  NORMALIZED_NAME_SQL = "lower(regexp_replace(name, '^[[:space:]]+|[[:space:]]+$', '', 'g'))".freeze

  belongs_to :user, optional: true
  has_many :expenses, dependent: :restrict_with_error

  scope :global, -> { where(user_id: nil) }
  scope :visible_to, ->(user) { where(user_id: [ nil, user.id ]) }

  before_validation :trim_name
  before_save :serialize_catalog_changes

  validates :name, presence: true
  validates :user, presence: true, if: -> { user_id.present? }
  validate :name_is_unique_in_visible_catalog
  validate :owner_is_unchanged, on: :update

  private

  def trim_name
    self.name = name.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "") if name
  end

  def name_is_unique_in_visible_catalog
    return if name.blank?

    candidates = Category.where("#{NORMALIZED_NAME_SQL} = lower(?)", name)
    candidates = candidates.where.not(id: id) if persisted?
    candidates = candidates.visible_to(user) if user_id.present? && user
    if candidates.exists?
      errors.add(:name, :taken, value: name)
    end
  end

  def owner_is_unchanged
    errors.add(:user_id, "no se puede cambiar") if will_save_change_to_user_id?
  end

  def serialize_catalog_changes
    # Saves run in a transaction. Serialize catalog writers before rechecking:
    # partial unique indexes alone cannot prevent global/private collisions.
    # Requires PostgreSQL's default READ COMMITTED isolation. Raw SQL,
    # update_all/update_columns and bulk inserts bypass this protection.
    self.class.connection.execute("LOCK TABLE categories IN SHARE ROW EXCLUSIVE MODE")
    trim_name
    self.class.uncached { name_is_unique_in_visible_catalog }
    owner_is_unchanged if persisted?
    throw :abort if errors.any?
  end
end
