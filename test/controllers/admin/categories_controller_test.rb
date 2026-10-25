require "test_helper"

class Admin::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_admin
    @category = Category.create!(name: "Compras", description: "Compras de comida")
  end

  test "lists only global categories and identifies protected defaults" do
    user = User.create!(name: "Ana", email: "private@example.com", password: "clave-segura")
    private_category = user.categories.create!(name: "Viaje privado")
    default = Category.create!(name: "Alimentos")

    get admin_categories_url

    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "td", text: @category.name
    assert_select "tbody tr", text: /Alimentos/ do
      assert_select ".badge", text: "Predeterminada"
      assert_select "a[href=?]", admin_category_path(default)
      assert_select "a[href=?]", edit_admin_category_path(default)
      assert_select "input[name='_method'][value='delete']", count: 0
    end
    assert_select "td", text: private_category.name, count: 0
    assert_select "a[href=?]", admin_category_path(private_category), count: 0
  end

  test "private categories return not found for every member action without changing data" do
    user = User.create!(name: "Ana", email: "private@example.com", password: "clave-segura")
    category = user.categories.create!(name: "Viaje privado", description: "Conservar")
    original = category.attributes

    get admin_category_url(category)
    assert_response :not_found
    get edit_admin_category_url(category)
    assert_response :not_found
    patch admin_category_url(category), params: { category: { name: "Cambio", user_id: nil } }
    assert_response :not_found
    assert_no_difference "Category.count" do
      delete admin_category_url(category)
      assert_response :not_found
    end
    assert_equal original, category.reload.attributes
  end

  test "creation ignores malicious ownership parameters and always creates a global category" do
    user = User.create!(name: "Ana", email: "private@example.com", password: "clave-segura")

    assert_difference "Category.global.count", 1 do
      assert_no_difference "user.categories.count" do
        post admin_categories_url, params: { category: { name: "Viaje", user_id: user.id } }
      end
    end

    category = Category.global.find_by!(name: "Viaje")
    assert_nil category.user_id
    assert_redirected_to admin_category_url(category)
  end

  test "updates ignore malicious ownership parameters while keeping ordinary fields editable" do
    user = User.create!(name: "Ana", email: "private@example.com", password: "clave-segura")

    patch admin_category_url(@category), params: { category: { name: "Comida", user_id: user.id } }

    assert_redirected_to admin_category_url(@category)
    assert_nil @category.reload.user_id
    assert_equal "Comida", @category.name
  end

  test "default show and edit identify protection and offer only description changes" do
    category = Category.create!(name: "Alimentos", description: "Original")

    get admin_category_url(category)
    assert_response :success
    assert_select ".badge", text: "Predeterminada"
    assert_select "form[action=?] input[name='_method'][value='delete']", admin_category_path(category), count: 0

    get edit_admin_category_url(category)
    assert_response :success
    assert_select "input[name='category[name]'][disabled][value='Alimentos']"
    assert_select "input[name='category[name]']:not([disabled])", count: 0
    assert_select "textarea[name='category[description]']:not([disabled])", text: "Original"
    assert_select ".form-text", text: "Categoría predeterminada: solo se puede modificar su descripción."
  end

  test "default rename is rejected with errors and keeps the protected form after rejection" do
    category = Category.create!(name: "Alimentos", description: "Original")
    original = category.attributes

    patch admin_category_url(category), params: { category: { name: "Comida", description: "Cambio" } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", text: /no se puede cambiar en una categoría predeterminada/
    assert_select "input[name='category[name]'][disabled][value='Alimentos']"
    assert_select "textarea", text: "Cambio"
    assert_equal original, category.reload.attributes
  end

  test "default description can be updated without changing its name or owner" do
    category = Category.create!(name: "Alimentos", description: "Original")
    user = User.create!(name: "Ana", email: "private@example.com", password: "clave-segura")

    patch admin_category_url(category), params: { category: { description: "Actualizada", user_id: user.id } }

    assert_redirected_to admin_category_url(category)
    assert_equal "Actualizada", category.reload.description
    assert_equal "Alimentos", category.name
    assert_nil category.user_id
    follow_redirect!
    assert_select "[role='status']", text: "Categoría actualizada correctamente."
  end

  test "direct default deletion is rejected with a clear message" do
    category = Category.create!(name: "Alimentos")
    original = category.attributes

    assert_no_difference "Category.count" do
      delete admin_category_url(category)
    end

    assert_redirected_to admin_category_url(category)
    assert_equal original, category.reload.attributes
    follow_redirect!
    assert_select "[role='alert']", text: "No se puede eliminar una categoría predeterminada."
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
    assert_equal "Compras", @category.reload.name
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
