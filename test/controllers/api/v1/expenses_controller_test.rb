require "test_helper"

class Api::V1::ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-ana")
    @other = User.create!(name: "Otro", email: "otro@example.com", password: "clave-otro", role: "admin")
    @category = Category.create!(name: "Alimentos")
    @second_category = Category.create!(name: "Transporte")
    @household = Household.create!(name: "Casa")
    @other_household = Household.create!(name: "Otro hogar")
    Membership.create!(user: @user, household: @household)
    Membership.create!(user: @other, household: @household)
    Membership.create!(user: @other, household: @other_household)
    @personal = @user.expenses.create!(description: "Personal", amount: "123.45", date: "2026-10-01", category: @category)
    @shared = @user.expenses.create!(description: "Compartido", amount: 200, date: "2026-10-02",
      category: @category, household: @household, notes: "Compra semanal")
    @latest = @user.expenses.create!(description: "Viaje", amount: 300, date: "2026-10-02", category: @second_category)
    @foreign = @other.expenses.create!(description: "Gasto privado", amount: 400, date: "2026-10-02",
      category: @category, household: @household)
    @headers = { "Authorization" => "Bearer #{@user.signed_id(purpose: :api_v1)}" }
  end

  test "every endpoint rejects missing and invalid tokens without changing expenses" do
    [ {}, { "Authorization" => "Bearer invalid" } ].each do |headers|
      assert_no_difference "Expense.count" do
        [ [ :get, api_v1_expenses_url ], [ :get, api_v1_expense_url(@personal) ],
          [ :post, api_v1_expenses_url ], [ :patch, api_v1_expense_url(@personal) ],
          [ :delete, api_v1_expense_url(@personal) ] ].each do |method, url|
          public_send(method, url, params: valid_params, headers: headers, as: :json)
          assert_response :unauthorized
          assert_equal "application/json", response.media_type
          assert response.parsed_body["error"].present?
        end
      end
      assert_equal "Personal", @personal.reload.description
    end
  end

  test "index returns only owned expenses in deterministic order with public associations" do
    get api_v1_expenses_url, headers: @headers, as: :json

    assert_response :ok
    assert_equal [ @latest.id, @shared.id, @personal.id ], response.parsed_body.map { |expense| expense["id"] }
    response.parsed_body.each { |expense| assert_public_expense(expense) }
    shared = response.parsed_body.find { |expense| expense["id"] == @shared.id }
    assert_equal({ "id" => @household.id, "name" => @household.name }, shared["household"])
    assert_equal({ "id" => @category.id, "name" => @category.name }, shared["category"])
    assert_equal "Compra semanal", shared["notes"]
    assert_nil response.parsed_body.last["household"]
    assert_not_includes response.body, @foreign.description
  end

  test "from filter is inclusive" do
    assert_index_ids({ from: "2026-10-02" }, [ @latest.id, @shared.id ])
  end

  test "to filter is inclusive" do
    assert_index_ids({ to: "2026-10-01" }, [ @personal.id ])
  end

  test "category filter" do
    assert_index_ids({ category_id: @category.id }, [ @shared.id, @personal.id ])
  end

  test "household filter does not expose other members expenses" do
    assert_index_ids({ household_id: @household.id }, [ @shared.id ])
  end

  test "filters combine including both date boundaries" do
    assert_index_ids({ from: "2026-10-02", to: "2026-10-02", category_id: @category.id,
      household_id: @household.id }, [ @shared.id ])
  end

  test "filters without matches return an empty array" do
    assert_index_ids({ household_id: @other_household.id }, [])
    assert_index_ids({ from: "2026-10-03", to: "2026-10-01" }, [])
  end

  test "invalid date filters return JSON errors" do
    [ { from: "invalid" }, { to: "2026-02-30" }, { from: [ "2026-10-01" ] } ].each do |filters|
      get api_v1_expenses_url, params: filters, headers: @headers, as: :json
      assert_errors :bad_request
    end
  end

  test "show returns an owned expense" do
    get api_v1_expense_url(@personal), headers: @headers, as: :json

    assert_response :ok
    assert_public_expense(response.parsed_body)
    assert_equal @personal.id, response.parsed_body["id"]
    assert_equal "123.45", response.parsed_body["amount"]
    assert_equal "2026-10-01", response.parsed_body["date"]
    assert_nil response.parsed_body["household"]
  end

  test "foreign and nonexistent expenses give identical errors for show update and delete" do
    [ :get, :patch, :delete ].each do |method|
      [ @foreign.id, Expense.maximum(:id) + 1 ].each do |id|
        assert_no_difference "Expense.count" do
          public_send(method, api_v1_expense_url(id), params: { description: "Changed" }, headers: @headers, as: :json)
        end
        assert_errors :not_found
        assert_equal({ "errors" => [ "Gasto no encontrado." ] }, response.parsed_body)
      end
    end
    assert_equal "Gasto privado", @foreign.reload.description
  end

  test "admin role cannot access another user's expenses" do
    headers = { "Authorization" => "Bearer #{@other.signed_id(purpose: :api_v1)}" }
    get api_v1_expenses_url, headers: headers, as: :json
    assert_equal [ @foreign.id ], response.parsed_body.map { |expense| expense["id"] }
    get api_v1_expense_url(@personal), headers: headers, as: :json
    assert_errors :not_found
  end

  test "create personal expense assigns token owner and ignores supplied user_id" do
    assert_difference "@user.expenses.count", 1 do
      assert_no_difference "@other.expenses.count" do
        post api_v1_expenses_url, params: valid_params.merge(user_id: @other.id), headers: @headers, as: :json
      end
    end

    assert_response :created
    assert_public_expense(response.parsed_body)
    expense = @user.expenses.find(response.parsed_body["id"])
    assert_equal "Supermercado", expense.description
    assert_equal BigDecimal("32500"), expense.amount
    assert_equal Date.new(2026, 10, 2), expense.date
    assert_equal "Compra semanal", expense.notes
    assert_equal @category, expense.category
    assert_nil expense.household
  end

  test "create expense in a household with membership" do
    assert_difference "@user.expenses.count", 1 do
      post api_v1_expenses_url, params: valid_params.merge(household_id: @household.id), headers: @headers, as: :json
    end

    assert_response :created
    assert_public_expense(response.parsed_body)
    assert_equal @household.id, @user.expenses.find(response.parsed_body["id"]).household_id
  end

  test "create rejects foreign and nonexistent households" do
    [ @other_household.id, Household.maximum(:id) + 1 ].each do |id|
      assert_no_difference "Expense.count" do
        post api_v1_expenses_url, params: valid_params.merge(household_id: id), headers: @headers, as: :json
      end
      assert_errors :unprocessable_entity
    end
  end

  test "update own expense changes permitted attributes but ignores user_id" do
    patch api_v1_expense_url(@personal), params: { description: "Actualizado", amount: "42.50", date: "2026-10-03",
      notes: "Nueva nota", category_id: @second_category.id, household_id: @household.id, user_id: @other.id },
      headers: @headers, as: :json

    assert_response :ok
    assert_public_expense(response.parsed_body)
    @personal.reload
    assert_equal @user.id, @personal.user_id
    assert_equal "Actualizado", @personal.description
    assert_equal BigDecimal("42.50"), @personal.amount
    assert_equal Date.new(2026, 10, 3), @personal.date
    assert_equal "Nueva nota", @personal.notes
    assert_equal @second_category.id, @personal.category_id
    assert_equal @household.id, @personal.household_id
  end

  test "update can make a household expense personal" do
    patch api_v1_expense_url(@shared), params: { household_id: nil }, headers: @headers, as: :json

    assert_response :ok
    assert_nil @shared.reload.household_id
    assert_nil response.parsed_body["household"]
  end

  test "update rejects foreign household and persists no changes" do
    previous = @personal.attributes
    patch api_v1_expense_url(@personal), params: { household_id: @other_household.id, description: "Changed" },
      headers: @headers, as: :json

    assert_errors :unprocessable_entity
    assert_equal previous, @personal.reload.attributes
  end

  test "delete removes own expense with no response body" do
    assert_difference "Expense.count", -1 do
      delete api_v1_expense_url(@personal), headers: @headers, as: :json
    end

    assert_response :no_content
    assert_empty response.body
    assert_not Expense.exists?(@personal.id)
    assert Expense.exists?(@foreign.id)
  end

  test "model validation failures on create return errors without persisting" do
    [ { description: "" }, { amount: 0 }, { amount: "invalid" }, { date: nil },
      { category_id: nil }, { category_id: Category.maximum(:id) + 1 } ].each do |invalid|
      assert_no_difference "Expense.count" do
        post api_v1_expenses_url, params: valid_params.merge(invalid), headers: @headers, as: :json
      end
      assert_errors :unprocessable_entity
    end
  end

  test "model validation failures on update return errors and preserve stored expense" do
    previous = @personal.attributes
    patch api_v1_expense_url(@personal), params: { amount: -1, description: "" }, headers: @headers, as: :json

    assert_errors :unprocessable_entity
    assert_equal previous, @personal.reload.attributes
  end

  private

  def valid_params
    { description: "Supermercado", amount: 32500, date: "2026-10-02", category_id: @category.id,
      household_id: nil, notes: "Compra semanal" }
  end

  def assert_index_ids(filters, ids)
    get api_v1_expenses_url, params: filters, headers: @headers, as: :json
    assert_response :ok
    assert_equal ids, response.parsed_body.map { |expense| expense["id"] }
  end

  def assert_public_expense(expense)
    assert_equal "application/json", response.media_type
    assert_equal %w[amount category date description household id notes], expense.keys.sort
    assert_equal %w[id name], expense["category"].keys.sort
    assert_equal %w[id name], expense["household"].keys.sort if expense["household"]
    assert_no_private_data
  end

  def assert_errors(status)
    assert_response status
    assert_equal "application/json", response.media_type
    assert_equal [ "errors" ], response.parsed_body.keys
    assert_kind_of Array, response.parsed_body["errors"]
    assert response.parsed_body["errors"].all? { |error| error.is_a?(String) }
    assert_not_empty response.parsed_body["errors"]
    assert_no_private_data
  end

  def assert_no_private_data
    %w[password password_digest token user_id email].each { |key| assert_not_includes response.body, "\"#{key}\"" }
    [ @user, @other ].each do |user|
      assert_not_includes response.body, user.password_digest
      assert_not_includes response.body, user.email
    end
  end
end
