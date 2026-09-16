require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = User.new(name: "Ana", email: "ana@example.com", password: "clave-segura")
  end

  test "is valid with required attributes" do
    assert @user.valid?
  end

  test "requires nonblank mandatory attributes" do
    %i[name email password_digest role].each do |attribute|
      [ nil, "", "   " ].each do |value|
        user = @user.dup
        user.public_send("#{attribute}=", value)

        assert_not user.valid?
        assert user.errors.added?(attribute, :blank)
      end
    end
  end

  test "requires a password on creation" do
    user = User.new(name: "Ana", email: "ana@example.com")

    assert_not user.valid?
    assert user.errors.added?(:password, :blank)
  end

  test "requires a unique email" do
    @user.save!
    duplicate = User.new(name: "Otra persona", email: @user.email, password: "otra-clave")

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:email, :taken, value: @user.email)
  end

  test "allows distinct emails" do
    @user.save!

    assert User.new(name: "Luis", email: "luis@example.com", password: "otra-clave").valid?
  end

  test "database rejects duplicate emails when validations are bypassed" do
    @user.save!
    duplicate = User.new(name: "Luis", email: @user.email, password: "otra-clave")

    assert_raises(ActiveRecord::RecordNotUnique) do
      User.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "defaults to user role" do
    assert_equal "user", @user.role
    @user.save!
    assert_equal "user", @user.reload.role
  end

  test "allows user and admin roles" do
    %w[user admin].each do |role|
      @user.role = role

      assert @user.valid?
    end
  end

  test "rejects other roles" do
    %w[guest superadmin ADMIN].each do |role|
      @user.role = role

      assert_not @user.valid?
      assert @user.errors.added?(:role, :inclusion, value: role)
    end
  end

  test "stores a password hash and authenticates the persisted user" do
    @user.save!
    user = User.find(@user.id)

    assert_not_equal "clave-segura", user.password_digest
    assert_equal user, user.authenticate("clave-segura")
    assert_equal false, user.authenticate("incorrecta")
  end

  test "rejects mismatched password confirmation" do
    @user.password_confirmation = "diferente"

    assert_not @user.valid?
    assert @user.errors.of_kind?(:password_confirmation, :confirmation)
  end

  test "rejects passwords longer than 72 bytes" do
    @user.password = "a" * 73

    assert_not @user.valid?
    assert @user.errors.of_kind?(:password, :password_too_long)
  end

  test "allows updating a persisted user without a new password" do
    @user.save!
    user = User.find(@user.id)

    assert user.update(name: "Ana Maria")
    assert_equal user, user.authenticate("clave-segura")
  end

  test "has multiple households through memberships" do
    @user.save!
    first_household = Household.create!(name: "Casa")
    second_household = Household.create!(name: "Otra casa")
    first = @user.memberships.create!(household: first_household, role: "owner")
    second = @user.memberships.create!(household: second_household)

    assert_equal [ first, second ], @user.memberships.order(:id).to_a
    assert_equal [ first_household, second_household ], @user.households.order(:id).to_a
  end

  test "destroying a user destroys memberships and preserves households and other memberships" do
    @user.save!
    household = Household.create!(name: "Casa")
    other_user = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")
    membership = @user.memberships.create!(household: household)
    other_membership = other_user.memberships.create!(household: household)

    assert_difference "Membership.count", -1 do
      @user.destroy!
    end

    assert_not Membership.exists?(membership.id)
    assert Membership.exists?(other_membership.id)
    assert Household.exists?(household.id)
    assert User.exists?(other_user.id)
  end
end
