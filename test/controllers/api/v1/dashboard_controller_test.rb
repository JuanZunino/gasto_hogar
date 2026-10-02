require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-ana")
    @other = User.create!(name: "Otro", email: "otro@example.com", password: "clave-otro")
    @food = Category.create!(name: "Alimentos")
    @services = Category.create!(name: "Servicios")
    @transport = Category.create!(name: "Transporte")
    @foreign_category = Category.create!(name: "Categoría ajena")
    @household = Household.create!(name: "Casa")
    Membership.create!(user: @user, household: @household, role: "owner")
    Membership.create!(user: @other, household: @household, role: "member")
    expense(@user, @food, "10.10", "2026-09-30")
    expense(@user, @food, "20.20", "2026-10-01", @household)
    expense(@user, @food, "30.30", "2026-10-31")
    expense(@user, @services, "80.00", "2026-10-15")
    expense(@user, @transport, "60.60", "2026-11-01")
    expense(@other, @food, "1000.00", "2026-10-01", @household)
    expense(@other, @foreign_category, "2000.00", "2026-10-15")
    @token = @user.signed_id(purpose: :api_v1)
    @headers = { "Authorization" => "Bearer #{@token}" }
  end

  test "requires a valid bearer token" do
    [ {}, { "Authorization" => "Bearer invalid" } ].each do |headers|
      get api_v1_dashboard_url, headers: headers, as: :json

      assert_response :unauthorized
      assert_equal "application/json", response.media_type
      assert response.parsed_body["error"].present?
    end
  end

  test "sums counts and groups only owned expenses ordering totals descending and ties by category id" do
    get api_v1_dashboard_url, params: { user_id: @other.id }, headers: @headers, as: :json

    assert_dashboard "201.20", 5, [ category_total(@services, "80.00"),
      category_total(@food, "60.60"), category_total(@transport, "60.60") ]
  end

  test "from is inclusive and applies to all aggregates" do
    get api_v1_dashboard_url, params: { from: "2026-10-01" }, headers: @headers, as: :json

    assert_dashboard "191.10", 4, [ category_total(@services, "80.00"),
      category_total(@transport, "60.60"), category_total(@food, "50.50") ]
  end

  test "to is inclusive and applies to all aggregates" do
    get api_v1_dashboard_url, params: { to: "2026-10-31" }, headers: @headers, as: :json

    assert_dashboard "140.60", 4, [ category_total(@services, "80.00"), category_total(@food, "60.60") ]
  end

  test "combined dates include both boundaries and apply to all aggregates" do
    get api_v1_dashboard_url, params: { from: "2026-10-01", to: "2026-10-31" }, headers: @headers, as: :json

    assert_dashboard "130.50", 3, [ category_total(@services, "80.00"), category_total(@food, "50.50") ]
  end

  test "same day range excludes shared household expenses owned by another user" do
    get api_v1_dashboard_url, params: { from: "2026-10-01", to: "2026-10-01" }, headers: @headers, as: :json

    assert_dashboard "20.20", 1, [ category_total(@food, "20.20") ]
  end

  test "user without expenses receives empty aggregates even if other household members have expenses" do
    user = User.create!(name: "Sin gastos", email: "sin-gastos@example.com", password: "clave-nueva")
    Membership.create!(user: user, household: @household)
    get api_v1_dashboard_url, headers: { "Authorization" => "Bearer #{user.signed_id(purpose: :api_v1)}" }, as: :json

    assert_dashboard "0.00", 0, []
  end

  test "period without expenses returns empty aggregates" do
    get api_v1_dashboard_url, params: { from: "2027-01-01", to: "2027-01-31" }, headers: @headers, as: :json

    assert_dashboard "0.00", 0, []
  end

  test "inverted period returns empty aggregates" do
    get api_v1_dashboard_url, params: { from: "2026-11-01", to: "2026-10-01" }, headers: @headers, as: :json

    assert_dashboard "0.00", 0, []
  end

  test "invalid date filters return JSON errors" do
    [ { from: "invalid" }, { to: "2026-02-30" }, { from: [ "2026-10-01" ] } ].each do |filters|
      get api_v1_dashboard_url, params: filters, headers: @headers, as: :json

      assert_response :bad_request
      assert_equal "application/json", response.media_type
      assert_equal [ "errors" ], response.parsed_body.keys
      assert_kind_of Array, response.parsed_body["errors"]
      assert_not_empty response.parsed_body["errors"]
    end
  end

  private

  def expense(user, category, amount, date, household = nil)
    user.expenses.create!(description: "Descripción privada", notes: "Notas privadas", category: category,
      amount: amount, date: date, household: household)
  end

  def category_total(category, total)
    { "category" => { "id" => category.id, "name" => category.name }, "total" => total }
  end

  def assert_dashboard(total, count, categories)
    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal({ "total_expenses" => total, "expenses_count" => count, "expenses_by_category" => categories },
      response.parsed_body)
    %w[password password_digest token user_id email notes description].each do |key|
      assert_not_includes response.body, "\"#{key}\""
    end
    [ @user, @other ].each do |user|
      assert_not_includes response.body, user.password_digest
      assert_not_includes response.body, user.email
    end
    assert_not_includes response.body, @token
    assert_not_includes response.body, @foreign_category.name
  end
end
