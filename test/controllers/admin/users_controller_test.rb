require "test_helper"

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_admin
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "original-segura", role: "user")
    @attributes = { name: "Luis", email: "luis@example.com", password: "nueva-segura",
      password_confirmation: "nueva-segura", role: "admin" }
  end

  test "lists users with actions without exposing credentials" do
    get admin_users_url

    assert_response :success
    [ "Ana", "ana@example.com", "user" ].each { |value| assert_select "td", text: value }
    assert_select "a[href=?]", new_admin_user_path
    assert_select "a[href=?]", admin_user_path(@user)
    assert_select "a[href=?]", edit_admin_user_path(@user)
    assert_select "form[action=?] input[value='delete']", admin_user_path(@user)
    assert_no_credentials
  end

  test "shows safe user details" do
    get admin_user_url(@user)

    assert_response :success
    assert_select "h1", text: "Ana"
    assert_select "p", text: "Email: ana@example.com"
    assert_select "p", text: "Rol: user"
    assert_no_credentials
  end

  test "renders new form with virtual password fields and supported roles" do
    get new_admin_user_url

    assert_response :success
    assert_select "form[action=?]", admin_users_path do
      assert_select "input[name='user[name]'][required]"
      assert_select "input[name='user[email]'][type='email'][required]"
      %w[password password_confirmation].each do |field|
        assert_select "input[name=?][type='password'][required]", "user[#{field}]"
      end
      assert_role_options
    end
    assert_no_credentials
  end

  test "edit form never populates password fields" do
    get edit_admin_user_url(@user)

    assert_response :success
    assert_select "form[action=?]", admin_user_path(@user) do
      assert_select "input[name='user[name]'][value='Ana']"
      assert_select "input[name='user[email]'][value='ana@example.com']"
      %w[password password_confirmation].each do |field|
        assert_select "input[name=?][type='password']:not([required]):not([value])", "user[#{field}]"
      end
      assert_role_options
      assert_select "select[name='user[role]'] option[selected][value='user']"
    end
    assert_no_credentials
  end

  test "creates a user with a securely hashed password and flash" do
    assert_difference "User.count", 1 do
      post admin_users_url, params: { user: @attributes }
    end

    user = User.find_by!(email: "luis@example.com")
    assert_equal "Luis", user.name
    assert_equal "admin", user.role
    assert user.authenticate("nueva-segura")
    assert_not_equal "nueva-segura", user.password_digest
    assert_redirected_to admin_user_url(user)
    follow_redirect!
    assert_select "[role='status']", text: "Usuario creado correctamente."
    assert_no_credentials
    assert_not_includes response.body, user.password_digest
  end

  { name: "", email: "", password: "", password_confirmation: "diferente", role: "owner" }.each do |field, value|
    test "rejects invalid creation with #{field}" do
      assert_no_difference "User.count" do
        post admin_users_url, params: { user: @attributes.merge(field => value) }
      end

      assert_response :unprocessable_entity
      assert_select "[role='alert'] li", minimum: 1
      assert_role_options
      assert_no_credentials
      assert_select "input[type='password'][value]", count: 0
    end
  end

  test "rejects duplicate email and retains nonsensitive form values" do
    assert_no_difference "User.count" do
      post admin_users_url, params: { user: @attributes.merge(email: @user.email) }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_select "input[name='user[name]'][value='Luis']"
    assert_select "input[name='user[email]'][value=?]", @user.email
  end

  test "updates profile with blank passwords without changing digest" do
    digest = @user.password_digest
    patch admin_user_url(@user), params: { user: { name: "Actualizado", email: "nuevo@example.com",
      role: "admin", password: "", password_confirmation: "" } }

    assert_redirected_to admin_user_url(@user)
    assert_equal "Actualizado", @user.reload.name
    assert_equal "nuevo@example.com", @user.email
    assert_equal "admin", @user.role
    assert_equal digest, @user.password_digest
    assert @user.authenticate("original-segura")
    follow_redirect!
    assert_select "[role='status']", text: "Usuario actualizado correctamente."
  end

  test "updates profile with omitted password fields" do
    digest = @user.password_digest
    patch admin_user_url(@user), params: { user: { name: "Actualizado" } }

    assert_redirected_to admin_user_url(@user)
    assert_equal "Actualizado", @user.reload.name
    assert_equal digest, @user.password_digest
  end

  test "updates password securely" do
    digest = @user.password_digest
    patch admin_user_url(@user), params: { user: { password: "nueva-segura", password_confirmation: "nueva-segura" } }

    assert_redirected_to admin_user_url(@user)
    assert_not_equal digest, @user.reload.password_digest
    assert @user.authenticate("nueva-segura")
    assert_not @user.authenticate("original-segura")
  end

  [ { password: "nueva-segura", password_confirmation: "diferente" },
    { password: "nueva-segura", password_confirmation: "" },
    { password: "", password_confirmation: "diferente" },
    { name: "" }, { email: "" }, { role: "owner" } ].each_with_index do |attributes, index|
    test "invalid update #{index} preserves stored profile and password" do
      original = @user.attributes
      patch admin_user_url(@user), params: { user: attributes }

      assert_response :unprocessable_entity
      assert_select "[role='alert'] li", minimum: 1
      assert_equal original, @user.reload.attributes
      assert_select "input[type='password'][value]", count: 0
      assert_no_credentials
    end
  end

  test "does not permit assigning password digest" do
    digest = @user.password_digest
    patch admin_user_url(@user), params: { user: { name: "Actualizado", password_digest: "unsafe" } }

    assert_redirected_to admin_user_url(@user)
    assert_equal digest, @user.reload.password_digest
    assert_no_difference "User.count" do
      post admin_users_url, params: { user: @attributes.except(:password, :password_confirmation).merge(password_digest: digest) }
    end
    assert_response :unprocessable_entity
  end

  test "deletes user and memberships but preserves household" do
    household = Household.create!(name: "Casa")
    Membership.create!(user: @user, household: household)
    assert_no_difference "Household.count" do
      assert_difference [ "User.count", "Membership.count" ], -1 do
        delete admin_user_url(@user)
      end
    end

    assert_redirected_to admin_users_url
    follow_redirect!
    assert_select "[role='status']", text: "Usuario eliminado correctamente."
    assert_select "td", text: "ana@example.com", count: 0
  end

  test "preserves user with expenses and memberships and explains restriction" do
    household = Household.create!(name: "Casa")
    membership = Membership.create!(user: @user, household: household)
    expense = Expense.create!(user: @user, category: Category.create!(name: "Comida"),
      description: "Compra", amount: 10, date: Date.current)

    assert_no_difference [ "User.count", "Expense.count", "Membership.count" ] do
      delete admin_user_url(@user)
    end

    assert_redirected_to admin_user_url(@user)
    assert_equal @user, expense.reload.user
    assert_equal @user, membership.reload.user
    follow_redirect!
    assert_select "[role='alert']", text: "No se pudo eliminar el usuario porque tiene gastos asociados."
  end

  test "returns not found for unknown user" do
    get admin_user_url(id: -1)
    assert_response :not_found
  end

  private

  def assert_no_credentials
    assert_not_includes response.body, @user.password_digest
    assert_not_includes response.body, "original-segura"
    assert_not_includes response.body, "nueva-segura"
    assert_select "input[name='user[password_digest]']", count: 0
  end

  def assert_role_options
    assert_select "select[name='user[role]'] option", count: 2
    %w[user admin].each { |role| assert_select "select[name='user[role]'] option[value=?]", role, text: role }
  end
end
