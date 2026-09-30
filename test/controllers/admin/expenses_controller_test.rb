require "test_helper"

class Admin::ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    @category = Category.create!(name: "Alimentos")
    @household = Household.create!(name: "Casa")
    @attributes = { description: "Compra", amount: "10.50", date: "2026-09-20", notes: "Mercado",
      user_id: @user.id, category_id: @category.id, household_id: @household.id }
    @expense = Expense.create!(@attributes)
  end

  test "lists expenses with associations and actions including personal expenses" do
    Expense.create!(@attributes.merge(description: "Personal", household_id: nil))
    get admin_expenses_url

    assert_response :success
    [ "2026-09-20", "Compra", "10.50", "Ana", "Alimentos", "Casa", "Personal" ].each do |value|
      assert_select "td", text: value
    end
    assert_select "a[href=?]", new_admin_expense_path
    assert_select "a[href=?]", admin_expense_path(@expense)
    assert_select "a[href=?]", edit_admin_expense_path(@expense)
    assert_select "form[action=?] input[name='_method'][value='delete']", admin_expense_path(@expense)
  end

  test "shows an empty list" do
    @expense.destroy!
    get admin_expenses_url

    assert_response :success
    assert_select "p", text: "No hay gastos registrados."
  end

  test "shows all expense details" do
    get admin_expense_url(@expense)

    assert_response :success
    assert_select "h1", text: "Compra"
    [ "2026-09-20", "10.50", "Ana", "Alimentos", "Casa", "Mercado" ].each do |value|
      assert_select "p", text: /#{Regexp.escape(value)}/
    end
    @expense.update!(household: nil)
    get admin_expense_url(@expense)
    assert_select "p", text: "Hogar: Personal"
  end

  test "renders new form with required fields and existing associations" do
    get new_admin_expense_url

    assert_response :success
    assert_select "form[action=?]", admin_expenses_path do
      assert_select "input[type='text'][name='expense[description]'][required]"
      assert_select "input[type='number'][name='expense[amount]'][required]"
      assert_select "input[type='date'][name='expense[date]'][required]"
      assert_select "textarea[name='expense[notes]']:not([required])"
      assert_form_options
    end
  end

  test "renders edit form with existing values" do
    get edit_admin_expense_url(@expense)

    assert_response :success
    assert_select "form[action=?]", admin_expense_path(@expense) do
      assert_select "input[name='expense[description]'][value='Compra']"
      assert_select "input[name='expense[amount]'][value='10.5']"
      assert_select "input[name='expense[date]'][value='2026-09-20']"
      assert_select "textarea", text: "Mercado"
      { user_id: @user.id, category_id: @category.id, household_id: @household.id }.each do |field, id|
        assert_select "select[name=?] option[selected][value=?]", "expense[#{field}]", id.to_s
      end
    end
  end

  test "creates household and personal expenses and displays flash" do
    [ @household.id, "" ].each do |household_id|
      assert_difference "Expense.count", 1 do
        post admin_expenses_url, params: { expense: @attributes.merge(household_id: household_id) }
      end

      expense = Expense.order(:id).last
      if household_id.present?
        assert_equal household_id, expense.household_id
      else
        assert_nil expense.household_id
      end
      assert_equal "Compra", expense.description
      assert_equal BigDecimal("10.50"), expense.amount
      assert_equal Date.new(2026, 9, 20), expense.date
      assert_equal "Mercado", expense.notes
      assert_equal @user, expense.user
      assert_equal @category, expense.category
      assert_redirected_to admin_expense_url(expense)
      follow_redirect!
      assert_select "[role='status']", text: "Gasto creado correctamente."
    end
  end

  {
    description: [ "" ], amount: [ "", "0", "-1", "abc" ], date: [ "", "invalid" ],
    user_id: [ "", -1 ], category_id: [ "", -1 ]
  }.each do |field, values|
    values.each do |value|
      test "rejects creation with #{field} #{value.inspect}" do
        assert_no_difference "Expense.count" do
          post admin_expenses_url, params: { expense: @attributes.merge(field => value) }
        end

        assert_response :unprocessable_entity
        assert_select "[role='alert'] li", minimum: 1
        assert_select "textarea", text: "Mercado"
        assert_form_options
      end
    end
  end

  test "updates all fields and displays flash" do
    user = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")
    category = Category.create!(name: "Transporte")
    household = Household.create!(name: "Otro hogar")
    attributes = { description: "Viaje", amount: "20.75", date: "2026-09-21", notes: "Taxi",
      user_id: user.id, category_id: category.id, household_id: household.id }

    patch admin_expense_url(@expense), params: { expense: attributes }

    assert_redirected_to admin_expense_url(@expense)
    @expense.reload
    attributes.except(:amount, :date).each do |field, value|
      assert_equal value, @expense.public_send(field)
    end
    assert_equal BigDecimal("20.75"), @expense.amount
    assert_equal Date.new(2026, 9, 21), @expense.date
    follow_redirect!
    assert_select "[role='status']", text: "Gasto actualizado correctamente."
  end

  test "can clear household and optional notes" do
    patch admin_expense_url(@expense), params: { expense: { household_id: "", notes: "" } }

    assert_redirected_to admin_expense_url(@expense)
    assert_nil @expense.reload.household_id
    assert_equal "", @expense.notes
  end

  test "invalid update preserves stored values and renders errors and selected options" do
    original = @expense.attributes
    patch admin_expense_url(@expense), params: { expense: { amount: "0", notes: "Conservar" } }

    assert_response :unprocessable_entity
    assert_select "[role='alert'] li", minimum: 1
    assert_select "textarea", text: "Conservar"
    assert_select "select[name='expense[household_id]'] option[selected][value=?]", @household.id.to_s
    assert_form_options
    assert_equal original, @expense.reload.attributes
  end

  test "deletes an expense and displays flash" do
    assert_difference "Expense.count", -1 do
      delete admin_expense_url(@expense)
    end

    assert_redirected_to admin_expenses_url
    follow_redirect!
    assert_select "[role='status']", text: "Gasto eliminado correctamente."
  end

  test "returns not found for an unknown expense" do
    get admin_expense_url(id: -1)

    assert_response :not_found
  end

  private

  def assert_form_options
    { user_id: @user, category_id: @category, household_id: @household }.each do |field, record|
      assert_select "select[name=?] option[value=?]", "expense[#{field}]", record.id.to_s, text: record.name
    end
    assert_select "select[name='expense[household_id]']:not([required]) option[value='']", text: "Personal"
  end
end
