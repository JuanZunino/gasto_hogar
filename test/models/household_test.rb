require "test_helper"

class HouseholdTest < ActiveSupport::TestCase
  test "is valid with a name and description" do
    household = Household.new(name: "Casa", description: "Gastos compartidos")

    assert household.valid?
  end

  test "requires a nonblank name" do
    [ nil, "", "   " ].each do |name|
      household = Household.new(name: name)

      assert_not household.valid?
      assert household.errors.added?(:name, :blank)
    end
  end

  test "allows an optional description" do
    [ nil, "" ].each do |description|
      assert Household.new(name: "Casa", description: description).valid?
    end
  end

  test "has multiple users through memberships" do
    household = Household.create!(name: "Casa")
    ana = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    luis = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")
    first = household.memberships.create!(user: ana, role: "owner")
    second = household.memberships.create!(user: luis)

    assert_equal [ first, second ], household.memberships.order(:id).to_a
    assert_equal [ ana, luis ], household.users.order(:id).to_a
  end

  test "destroying a household destroys its memberships and preserves users and other memberships" do
    household = Household.create!(name: "Casa")
    other_household = Household.create!(name: "Otra casa")
    user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    membership = household.memberships.create!(user: user)
    other_membership = other_household.memberships.create!(user: user)

    assert_difference "Membership.count", -1 do
      household.destroy!
    end

    assert_not Membership.exists?(membership.id)
    assert Membership.exists?(other_membership.id)
    assert User.exists?(user.id)
    assert Household.exists?(other_household.id)
  end
end
