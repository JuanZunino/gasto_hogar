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

  test "household dashboard includes all authors once and excludes personal and other household expenses" do
    outside = Household.create!(name: "Outside")
    expense(@other, @food, "9999.00", "2026-10-01", outside)
    expense(@user, @food, "20.20", "2026-10-01", @household)
    get api_v1_dashboard_url, params: { household_id: @household.id }, headers: @headers, as: :json
    assert_dashboard "1040.40", 3, [ category_total(@food, "1040.40") ]
  end

  test "household dates are inclusive and apply to all calculations" do
    expense(@other, @services, "5.00", "2026-10-02", @household)
    [ { from: "2026-10-01", to: "2026-10-01" }, { to: "2026-10-01" } ].each do |filters|
      get api_v1_dashboard_url, params: filters.merge(household_id: @household.id), headers: @headers, as: :json
      assert_dashboard "1020.20", 2, [ category_total(@food, "1020.20") ]
    end
    get api_v1_dashboard_url, params: { household_id: @household.id, from: "2026-10-02" }, headers: @headers, as: :json
    assert_dashboard "5.00", 1, [ category_total(@services, "5.00") ]
    get api_v1_dashboard_url, params: { household_id: @household.id, from: "2027-01-01" }, headers: @headers, as: :json
    assert_dashboard "0.00", 0, []
    get api_v1_dashboard_url, params: { household_id: @household.id, from: "invalid" }, headers: @headers, as: :json
    assert_response :bad_request
    assert response.parsed_body["errors"].present?
  end

  test "leaving household removes own shared amounts and revokes joint dashboard without deleting history" do
    @user.memberships.find_by!(household: @household).destroy!
    get api_v1_dashboard_url, headers: @headers, as: :json
    assert_dashboard "181.00", 4, [ category_total(@services, "80.00"),
      category_total(@transport, "60.60"), category_total(@food, "40.40") ]
    get api_v1_dashboard_url, params: { household_id: @household.id }, headers: @headers, as: :json
    assert_response :not_found
    assert_equal({ "errors" => [ "Hogar no encontrado." ] }, response.parsed_body)

    headers = { "Authorization" => "Bearer #{@other.signed_id(purpose: :api_v1)}" }
    get api_v1_dashboard_url, params: { household_id: @household.id }, headers: headers, as: :json
    assert_dashboard "1020.20", 2, [ category_total(@food, "1020.20") ]
  end

  test "global administrator cannot request outsider or nonexistent household statistics" do
    @user.update!(role: "admin")
    outside = Household.create!(name: "Outside")
    [ outside.id, Household.maximum(:id) + 1 ].each do |id|
      get api_v1_dashboard_url, params: { household_id: id }, headers: @headers, as: :json
      assert_response :not_found
      assert_equal({ "errors" => [ "Hogar no encontrado." ] }, response.parsed_body)
    end
  end

  test "member without own expenses can see household statistics and an empty home returns zeros" do
    member = User.create!(name: "Member", email: "member-dashboard@example.com", password: "clave-segura")
    Membership.create!(user: member, household: @household)
    headers = { "Authorization" => "Bearer #{member.signed_id(purpose: :api_v1)}" }
    get api_v1_dashboard_url, params: { household_id: @household.id }, headers: headers, as: :json
    assert_dashboard "1020.20", 2, [ category_total(@food, "1020.20") ]
    empty = Household.create!(name: "Empty")
    Membership.create!(user: member, household: empty)
    get api_v1_dashboard_url, params: { household_id: empty.id }, headers: headers, as: :json
    assert_dashboard "0.00", 0, []
  end

  test "household groups homonymous private categories by id without exposing private catalogs" do
    first = @user.categories.create!(name: "Especial")
    second = @other.categories.create!(name: "Especial")
    expense(@user, first, "7.00", "2026-10-03", @household)
    expense(@other, second, "7.00", "2026-10-03", @household)
    get api_v1_dashboard_url, params: { household_id: @household.id, from: "2026-10-03" }, headers: @headers, as: :json
    assert_dashboard "14.00", 2, [ category_total(first, "7.00"), category_total(second, "7.00") ]
    get api_v1_categories_url, headers: @headers, as: :json
    assert_not_includes response.parsed_body.map { |category| category["id"] }, second.id
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
