require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_admin
    @category = Category.create!(name: "Alimentos", description: "Compras de comida")
  end

  test "lists categories and action links" do
    get admin_categories_url

    assert_response :success
    assert_select "td", text: @category.name
    assert_select "a[href=?]", new_admin_category_path
    assert_select "a[href=?]", admin_category_path(@category)
    assert_select "a[href=?]", edit_admin_category_path(@category)
    assert_select "form input[name='_method'][value='delete']"
  end

  test "shows an empty list" do
    @category.destroy!
    get admin_categories_url

    assert_response :success
    assert_select "p", text: "No hay categorías registradas."
  end

  test "shows a category" do
    get admin_category_url(@category)

    assert_response :success
    assert_select "h1", text: @category.name
    assert_select "p", text: /Compras de comida/
  end

  test "renders the new form" do
    get new_admin_category_url

    assert_response :success
    assert_select "form[action=?]", admin_categories_path do
      assert_select "input[name='category[name]']"
      assert_select "textarea[name='category[description]']"
    end
  end

  test "renders the edit form with existing values" do
    get edit_admin_category_url(@category)

    assert_response :success
    assert_select "form[action=?]", admin_category_path(@category) do
      assert_select "input[name='category[name]'][value=?]", @category.name
      assert_select "textarea", text: @category.description
    end
  end

  test "creates a category and displays a flash message" do
    assert_difference "Category.count", 1 do
      post admin_categories_url, params: { category: { name: "Transporte", description: "Viajes" } }
    end

    category = Category.find_by!(name: "Transporte")
    assert_equal "Viajes", category.description
    assert_redirected_to admin_category_url(category)
    follow_redirect!
    assert_select "[role='status']", text: "Categoría creada correctamente."
  end

  test "invalid creation displays errors and retains form values" do
    assert_no_difference "Category.count" do
      post admin_categories_url, params: { category: { name: "", description: "Conservar" } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_select "textarea", text: "Conservar"
  end

  test "rejects duplicate names" do
    assert_no_difference "Category.count" do
      post admin_categories_url, params: { category: { name: @category.name } }
    end

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
  end

  test "updates a category and displays a flash message" do
    patch admin_category_url(@category), params: { category: { name: "Comida", description: "Actualizada" } }

    assert_redirected_to admin_category_url(@category)
    assert_equal "Comida", @category.reload.name
    assert_equal "Actualizada", @category.description
    follow_redirect!
    assert_select "[role='status']", text: "Categoría actualizada correctamente."
  end

  test "invalid update displays errors without changing the record" do
    patch admin_category_url(@category), params: { category: { name: "", description: "Conservar" } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_select "textarea", text: "Conservar"
    assert_equal "Alimentos", @category.reload.name
    assert_equal "Compras de comida", @category.description
  end

  test "deletes an unused category and displays a flash message" do
    assert_difference "Category.count", -1 do
      delete admin_category_url(@category)
    end

    assert_redirected_to admin_categories_url
    follow_redirect!
    assert_select "[role='status']", text: "Categoría eliminada correctamente."
  end

  test "preserves categories with expenses and explains why deletion failed" do
    user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    expense = Expense.create!(description: "Compra", amount: "10.50", date: Date.current,
      user: user, category: @category)

    assert_no_difference [ "Category.count", "Expense.count" ] do
      delete admin_category_url(@category)
    end

    assert_redirected_to admin_category_url(@category)
    assert_equal @category, expense.reload.category
    follow_redirect!
    assert_select "[role='alert']", text: "No se pudo eliminar la categoría porque tiene gastos asociados."
  end

  test "returns not found for an unknown category" do
    get admin_category_url(id: -1)

    assert_response :not_found
  end
end
