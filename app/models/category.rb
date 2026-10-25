class Category < ApplicationRecord
  DEFAULT_NAMES = %w[Alimentos Servicios Transporte Salud Educación Entretenimiento Hogar Mascotas Indumentaria Otros].freeze

  NORMALIZED_NAME_SQL = "lower(regexp_replace(name, '^[[:space:]]+|[[:space:]]+$', '', 'g'))".freeze

  belongs_to :user, optional: true
  has_many :expenses, dependent: :restrict_with_error

  scope :global, -> { where(user_id: nil) }
  scope :visible_to, ->(user) { where(user_id: [ nil, user.id ]) }

  before_validation :trim_name
  before_save :serialize_catalog_changes
  before_destroy :prevent_default_destruction

  validates :name, presence: true
  validates :user, presence: true, if: -> { user_id.present? }
  validate :name_is_unique_in_visible_catalog
  validate :owner_is_unchanged, on: :update
  validate :default_name_is_unchanged, on: :update

  def self.lock_catalog!
    connection.execute("LOCK TABLE categories IN SHARE ROW EXCLUSIVE MODE")
  end

  def default?
    user_id.nil? && default_name?(name)
  end

  private

  def default_name?(value)
    normalized = value.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "").downcase
    DEFAULT_NAMES.any? { |name| name.downcase == normalized }
  end

  def persisted_default?
    persisted? && user_id_in_database.nil? && default_name?(name_in_database)
  end

  def default_name_is_unchanged
    if persisted_default? && will_save_change_to_name?
      errors.add(:name, "no se puede cambiar en una categoría predeterminada")
    end
  end

  def prevent_default_destruction
    if persisted_default?
      errors.add(:base, "no se puede eliminar una categoría predeterminada")
      throw :abort
    end
  end

  def trim_name
    return if persisted_default? && !will_save_change_to_name?

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
    self.class.lock_catalog!
    trim_name
    self.class.uncached { name_is_unique_in_visible_catalog }
    owner_is_unchanged if persisted?
    default_name_is_unchanged if persisted?
    throw :abort if errors.any?
  end
end
