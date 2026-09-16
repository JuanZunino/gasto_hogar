require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    @household = Household.create!(name: "Casa")
    @membership = Membership.new(user: @user, household: @household)
  end

  test "belongs to a user and a household" do
    @membership.save!
    @membership.reload

    assert_equal @user, @membership.user
    assert_equal @household, @membership.household
  end

  test "requires a user and a household" do
    %i[user household].each do |association|
      membership = @membership.dup
      membership.public_send("#{association}=", nil)

      assert_not membership.valid?
      assert membership.errors.of_kind?(association, :blank)
    end
  end

  test "requires a nonblank role" do
    [ nil, "", "   " ].each do |role|
      @membership.role = role

      assert_not @membership.valid?
      assert @membership.errors.added?(:role, :blank)
    end
  end

  test "defaults to member role" do
    assert_equal "member", @membership.role
    @membership.save!
    assert_equal "member", @membership.reload.role
  end

  test "allows owner and member roles" do
    %w[owner member].each do |role|
      @membership.role = role

      assert @membership.valid?
    end
  end

  test "rejects other roles" do
    %w[user admin OWNER].each do |role|
      @membership.role = role

      assert_not @membership.valid?
      assert @membership.errors.added?(:role, :inclusion, value: role)
    end
  end

  test "rejects duplicate membership for the same user and household" do
    @membership.save!
    duplicate = Membership.new(user: @user, household: @household, role: "owner")

    assert_not duplicate.valid?
    assert duplicate.errors.added?(:user_id, :taken, value: @user.id)
  end

  test "allows the same user in different households" do
    @membership.save!
    other_household = Household.create!(name: "Otra casa")

    assert Membership.new(user: @user, household: other_household).valid?
  end

  test "allows different users in the same household" do
    @membership.save!
    other_user = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")

    assert Membership.new(user: other_user, household: @household).valid?
  end

  test "allows updating the role of an existing membership" do
    @membership.save!

    assert @membership.update(role: "owner")
    assert_equal "owner", @membership.reload.role
  end

  test "database rejects duplicate memberships when validations are bypassed" do
    @membership.save!
    duplicate = Membership.new(user: @user, household: @household)

    assert_raises(ActiveRecord::RecordNotUnique) do
      Membership.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "database requires both references" do
    %i[user household].each do |association|
      membership = @membership.dup
      membership.public_send("#{association}=", nil)

      assert_raises(ActiveRecord::NotNullViolation) do
        Membership.transaction(requires_new: true) { membership.save!(validate: false) }
      end
    end
  end

  test "database rejects references to nonexistent records" do
    %i[user_id household_id].each do |attribute|
      membership = @membership.dup
      membership.public_send("#{attribute}=", -1)

      assert_raises(ActiveRecord::InvalidForeignKey) do
        Membership.transaction(requires_new: true) { membership.save!(validate: false) }
      end
    end
  end
end
