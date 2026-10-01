module AdminSessionHelper
  def sign_in_admin
    admin = User.create!(name: "Administrador", email: "admin-tests@example.com",
      password: "admin-segura", role: "admin")
    post admin_login_url, params: { email: admin.email, password: "admin-segura" }
    assert_redirected_to admin_users_url
    admin
  end
end
