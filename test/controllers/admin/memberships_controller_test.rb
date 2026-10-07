require "test_helper"

class Admin::MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_admin
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    @household = Household.create!(name: "Casa")
    @membership = Membership.create!(user: @user, household: @household, role: "owner")
    @other_household = Household.create!(name: "Otro hogar")
    @attributes = { user_id: @user.id, household_id: @other_household.id, role: "member" }
  end

  test "lists memberships and actions" do
    get admin_memberships_url

    assert_response :success
    [ "Ana", "Casa", "owner" ].each { |value| assert_select "td", text: value }
    assert_select "a[href=?]", new_admin_membership_path
    assert_select "a[href=?]", admin_membership_path(@membership)
    assert_select "a[href=?]", edit_admin_membership_path(@membership)
    assert_select "form[action=?] input[value='delete']", admin_membership_path(@membership)
  end

  test "shows membership details" do
    get admin_membership_url(@membership)

    assert_response :success
    [ "Usuario: Ana", "Hogar: Casa", "Rol: owner" ].each { |value| assert_select "p", text: value }
  end

  test "renders new form with existing users households and only supported roles" do
    get new_admin_membership_url

    assert_response :success
    assert_select "form[action=?]", admin_memberships_path do
      assert_form_options
    end
  end

  test "renders edit form with current selections" do
    get edit_admin_membership_url(@membership)

    assert_response :success
    assert_select "form[action=?]", admin_membership_path(@membership) do
      assert_form_options
      assert_select "select[name='membership[user_id]'] option[selected][value=?]", @user.id.to_s
      assert_select "select[name='membership[household_id]'] option[selected][value=?]", @household.id.to_s
      assert_select "select[name='membership[role]'] option[selected][value='owner']"
    end
  end

  test "creates memberships with either supported role and displays flash" do
    %w[owner member].each do |role|
      household = Household.create!(name: "Casa #{role}")
      assert_difference "Membership.count", 1 do
        post admin_memberships_url, params: { membership: @attributes.merge(household_id: household.id, role: role) }
      end

      membership = Membership.find_by!(user: @user, household: household)
      assert_equal role, membership.role
      assert_redirected_to admin_membership_url(membership)
      follow_redirect!
      assert_select "[role='status']", text: "Integrante agregado correctamente."
    end
  end

  { user_id: [ "", -1 ], household_id: [ "", -1 ], role: [ "", "admin" ] }.each do |field, values|
    values.each do |value|
      test "rejects creation with #{field} #{value.inspect}" do
        assert_no_difference "Membership.count" do
          post admin_memberships_url, params: { membership: @attributes.merge(field => value) }
        end

        assert_response :unprocessable_entity
        assert_select "[role='alert'] li", minimum: 1
        assert_form_options
      end
    end
  end

  test "rejects duplicate user household pair" do
    assert_no_difference "Membership.count" do
      post admin_memberships_url, params: { membership: @attributes.merge(household_id: @household.id) }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_form_options
    assert_select "select[name='membership[user_id]'] option[selected][value=?]", @user.id.to_s
    assert_select "select[name='membership[household_id]'] option[selected][value=?]", @household.id.to_s
    assert_select "select[name='membership[role]'] option[selected][value='member']"
  end

  test "updates all fields and displays flash" do
    user = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")
    patch admin_membership_url(@membership), params: { membership: @attributes.merge(user_id: user.id) }

    assert_redirected_to admin_membership_url(@membership)
    assert_equal user, @membership.reload.user
    assert_equal @other_household, @membership.household
    assert_equal "member", @membership.role
    follow_redirect!
    assert_select "[role='status']", text: "Pertenencia actualizada correctamente."
  end

  test "rejects update to an existing pair without changing persisted values" do
    Membership.create!(@attributes)
    original = @membership.attributes
    patch admin_membership_url(@membership), params: { membership: @attributes }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_form_options
    assert_select "select[name='membership[household_id]'] option[selected][value=?]", @other_household.id.to_s
    assert_equal original, @membership.reload.attributes
  end

  test "rejects unsupported role on update" do
    patch admin_membership_url(@membership), params: { membership: { role: "admin" } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_form_options
    assert_equal "owner", @membership.reload.role
  end

  test "deletes membership without deleting user household or expenses" do
    category = Category.create!(name: "Comida")
    expense = Expense.create!(description: "Compra", amount: 10, date: Date.current,
      user: @user, household: @household, category: category)
    assert_no_difference [ "User.count", "Household.count", "Expense.count" ] do
      assert_difference "Membership.count", -1 do
        delete admin_membership_url(@membership)
      end
    end

    assert_equal @household, expense.reload.household
    assert_redirected_to admin_memberships_url
    follow_redirect!
    assert_select "[role='status']", text: "Pertenencia eliminada correctamente."
    assert_select "p", text: "No hay membresías registradas."
  end

  test "returns not found for unknown membership" do
    get admin_membership_url(id: -1)
    assert_response :not_found
  end

  private

  def assert_form_options
    assert_select "select[name='membership[user_id]'][required] option[value=?]", @user.id.to_s, text: "Ana"
    assert_select "select[name='membership[household_id]'][required] option[value=?]", @household.id.to_s, text: "Casa"
    assert_select "select[name='membership[household_id]'] option[value=?]", @other_household.id.to_s
    assert_select "select[name='membership[role]'] option", count: 2
    %w[owner member].each do |role|
      assert_select "select[name='membership[role]'] option[value=?]", role, text: role
    end
  end
end
