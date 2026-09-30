require "test_helper"

class Admin::HouseholdsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @household = Household.create!(name: "Casa", description: "Hogar compartido")
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    @membership = Membership.create!(user: @user, household: @household, role: "owner")
  end

  test "lists households and actions" do
    get admin_households_url

    assert_response :success
    assert_select "td", text: "Casa"
    assert_select "a[href=?]", new_admin_household_path
    assert_select "a[href=?]", admin_household_path(@household)
    assert_select "a[href=?]", edit_admin_household_path(@household)
    assert_select "form[action=?] input[value='delete']", admin_household_path(@household)
  end

  test "shows household details and only its current members" do
    other = Household.create!(name: "Otro")
    outsider = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")
    Membership.create!(user: outsider, household: other)
    get admin_household_url(@household)

    assert_response :success
    assert_select "h1", text: "Casa"
    assert_select "p", text: /Hogar compartido/
    [ "Ana", "ana@example.com", "owner" ].each { |value| assert_select "td", text: value }
    assert_select "td", text: "luis@example.com", count: 0
    @membership.destroy!
    get admin_household_url(@household)
    assert_select "p", text: "No hay integrantes en este hogar."
  end

  test "renders new and edit forms" do
    get new_admin_household_url
    assert_response :success
    assert_select "form[action=?]", admin_households_path do
      assert_select "input[name='household[name]'][required]"
      assert_select "textarea[name='household[description]']"
    end

    get edit_admin_household_url(@household)
    assert_response :success
    assert_select "form[action=?]", admin_household_path(@household) do
      assert_select "input[name='household[name]'][value='Casa']"
      assert_select "textarea", text: "Hogar compartido"
    end
  end

  test "creates a household with optional description and flash" do
    assert_difference "Household.count", 1 do
      post admin_households_url, params: { household: { name: "Nuevo", description: "" } }
    end

    assert_redirected_to admin_household_url(Household.find_by!(name: "Nuevo"))
    follow_redirect!
    assert_select "[role='status']", text: "Hogar creado correctamente."
  end

  test "invalid creation retains values and displays errors" do
    assert_no_difference "Household.count" do
      post admin_households_url, params: { household: { name: "", description: "Conservar" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_select "textarea", text: "Conservar"
  end

  test "updates a household and displays flash" do
    patch admin_household_url(@household), params: { household: { name: "Nuevo", description: "Actualizada" } }

    assert_redirected_to admin_household_url(@household)
    assert_equal "Nuevo", @household.reload.name
    assert_equal "Actualizada", @household.description
    follow_redirect!
    assert_select "[role='status']", text: "Hogar actualizado correctamente."
  end

  test "invalid update leaves persisted values unchanged" do
    original = @household.attributes
    patch admin_household_url(@household), params: { household: { name: "", description: "Conservar" } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_select "textarea", text: "Conservar"
    assert_equal original, @household.reload.attributes
  end

  test "deletes household and memberships but preserves users" do
    assert_no_difference "User.count" do
      assert_difference [ "Household.count", "Membership.count" ], -1 do
        delete admin_household_url(@household)
      end
    end

    assert_redirected_to admin_households_url
    follow_redirect!
    assert_select "[role='status']", text: "Hogar eliminado correctamente."
    assert_select "p", text: "No hay hogares registrados."
  end

  test "household with expenses cannot be deleted and preserves memberships" do
    category = Category.create!(name: "Comida")
    expense = Expense.create!(description: "Compra", amount: 10, date: Date.current,
      user: @user, category: category, household: @household)

    assert_no_difference [ "Household.count", "Membership.count", "Expense.count", "User.count" ] do
      delete admin_household_url(@household)
    end

    assert_redirected_to admin_household_url(@household)
    assert_equal @household, expense.reload.household
    assert_equal @household, @membership.reload.household
    follow_redirect!
    assert_select "[role='alert']", text: "No se pudo eliminar el hogar porque tiene gastos asociados."
  end

  test "returns not found for unknown household" do
    get admin_household_url(id: -1)
    assert_response :not_found
  end
end
