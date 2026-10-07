require "test_helper"

class Admin::SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "clave-admin", role: "admin")
    @user = User.create!(name: "Usuario", email: "user@example.com", password: "clave-user", role: "user")
  end

  test "login form is public and does not expose credentials" do
    get admin_login_url

    assert_response :success
    assert_select "form[action=?][method='post']", admin_login_path do
      assert_select "input[name='email'][type='email'][required]"
      assert_select "input[name='password'][type='password'][required]"
    end
    assert_select "form[action=?]", admin_logout_path, count: 0
    assert_select "nav[aria-label='Navegación administrativa']", count: 0
    assert_select "link[href=?][integrity][crossorigin='anonymous']",
      "https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css"
    assert_select "script[src=?][defer][integrity][crossorigin='anonymous']",
      "https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"
    assert_not_includes response.body, @admin.password_digest
  end

  %w[users categories households memberships expenses].each do |resource|
    test "protects every #{resource} CRUD action from visitors" do
      requests = [ [ :get, "/admin/#{resource}" ], [ :get, "/admin/#{resource}/new" ],
        [ :get, "/admin/#{resource}/1" ], [ :get, "/admin/#{resource}/1/edit" ],
        [ :post, "/admin/#{resource}" ], [ :patch, "/admin/#{resource}/1" ],
        [ :put, "/admin/#{resource}/1" ], [ :delete, "/admin/#{resource}/1" ] ]

      assert_no_difference [ "User.count", "Category.count", "Household.count", "Membership.count", "Expense.count" ] do
        requests.each do |method, path|
          public_send(method, path)
          assert_redirected_to admin_login_url
        end
      end
    end
  end

  [ [ "admin@example.com", "incorrecta" ], [ "inexistente@example.com", "clave-admin" ],
    [ "user@example.com", "clave-user" ], [ "", "" ] ].each_with_index do |(email, password), index|
    test "denies invalid or unauthorized login #{index}" do
      post admin_login_url, params: { email: email, password: password }

      assert_response :unprocessable_entity
      assert_select "[role='alert']", text: "Email o contraseña incorrectos, o acceso administrativo no autorizado."
      assert_nil session[:admin_user_id]
      assert_select "input[type='password'][value]", count: 0
      get admin_users_url
      assert_redirected_to admin_login_url
    end
  end

  test "admin login rotates session and stores only the user identifier as authentication data" do
    get admin_login_url
    previous_session_id = request.session.id
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }

    assert_redirected_to admin_users_url
    assert_equal @admin.id, session[:admin_user_id]
    assert_not_equal previous_session_id, request.session.id
    assert_empty session.to_hash.keys & %w[password password_digest password_confirmation email role user]
    follow_redirect!
    assert_select "[role='status']", text: "Sesión iniciada correctamente."
    assert_select "form[action=?] input[name='_method'][value='delete']", admin_logout_path
    assert_not_includes response.body, @admin.password_digest
  end

  test "authenticated admin can access every CRUD" do
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }

    %w[users categories households memberships expenses].each do |resource|
      get "/admin/#{resource}"
      assert_response :success
      assert_select "form[action=?]", admin_logout_path
      assert_admin_navigation
      get "/admin/#{resource}/new"
      assert_response :success
      assert_admin_navigation
    end
  end

  test "logout resets session and removes administrative access" do
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }
    previous_session_id = request.session.id
    delete admin_logout_url

    assert_redirected_to admin_login_url
    assert_nil session[:admin_user_id]
    assert_not_equal previous_session_id, request.session.id
    follow_redirect!
    assert_select "[role='status']", text: "Sesión cerrada correctamente."
    assert_select "form[action=?]", admin_logout_path, count: 0
    assert_select "nav[aria-label='Navegación administrativa']", count: 0
    get admin_users_url
    assert_redirected_to admin_login_url
  end

  test "role revocation immediately removes access" do
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }
    @admin.update!(role: "user")
    get admin_expenses_url

    assert_redirected_to admin_login_url
    assert_nil session[:admin_user_id]
  end

  test "deleted administrator session no longer grants access" do
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }
    @admin.destroy!
    get admin_users_url

    assert_redirected_to admin_login_url
    assert_nil session[:admin_user_id]
  end

  test "failed login clears an existing admin session" do
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }
    post admin_login_url, params: { email: @user.email, password: "clave-user" }

    assert_response :unprocessable_entity
    assert_select "nav[aria-label='Navegación administrativa']", count: 0
    assert_nil session[:admin_user_id]
    get admin_users_url
    assert_redirected_to admin_login_url
  end

  private

  def assert_admin_navigation
    assert_select "nav.navbar" do
      { "GastoHogar" => admin_expenses_path, "Gastos" => admin_expenses_path,
        "Categorías" => admin_categories_path, "Hogares" => admin_households_path,
        "Membresías" => admin_memberships_path, "Usuarios" => admin_users_path }.each do |label, path|
        assert_select "a[href=?]", path, text: label
      end
      assert_select "button[data-bs-toggle='collapse'][data-bs-target='#admin-navbar'][aria-controls='admin-navbar']"
      assert_select "#admin-navbar.collapse.navbar-collapse"
      assert_select "form[action=?] input[name='_method'][value='delete']", admin_logout_path
    end
  end
end
