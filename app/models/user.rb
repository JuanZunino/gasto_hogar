class User < ApplicationRecord
  has_secure_password

  has_many :memberships, dependent: :destroy
  has_many :households, through: :memberships

  validates :name, :password_digest, presence: true
  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: %w[user admin] }
end
