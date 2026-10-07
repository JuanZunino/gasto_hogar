require "application_system_test_case"

class AdminNavigationTest < ApplicationSystemTestCase
  setup do
    @admin = User.create!(name: "Administrador", email: "admin-system@example.com",
      password: "clave-system-segura", role: "admin")
  end

  test "administrator logs in navigates and loses access after logout" do
    visit admin_login_path
    assert_selector "h1", text: "Iniciar sesión administrativa"
    assert_no_selector "nav[aria-label='Navegación administrativa']"

    fill_in "Email", with: @admin.email
    fill_in "Contraseña", with: "clave-system-segura"
    click_button "Iniciar sesión"

    assert_current_path admin_users_path
    within "nav[aria-label='Navegación administrativa']" do
      assert_link "Gastos", href: admin_expenses_path
      assert_link "Categorías", href: admin_categories_path
      assert_link "Hogares", href: admin_households_path
      assert_link "Membresías", href: admin_memberships_path
      assert_link "Usuarios", href: admin_users_path
      click_link "Gastos", exact: true
    end

    assert_current_path admin_expenses_path
    assert_selector "h1", text: "Gastos"

    click_button "Cerrar sesión"
    assert_current_path admin_login_path
    assert_selector "[role='status']", text: "Sesión cerrada correctamente."
    assert_no_selector "nav[aria-label='Navegación administrativa']"

    visit admin_expenses_path
    assert_current_path admin_login_path
    assert_selector "[role='alert']", text: "Debes iniciar sesión como administrador."
    assert_selector "h1", text: "Iniciar sesión administrativa"
    assert_no_selector "nav[aria-label='Navegación administrativa']"
  end
end
