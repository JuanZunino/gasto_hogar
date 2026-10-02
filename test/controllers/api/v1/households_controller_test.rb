require "test_helper"

class Api::V1::HouseholdsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-ana")
    @other = User.create!(name: "Otro", email: "otro@example.com", password: "clave-otro", role: "admin")
    @outsider = User.create!(name: "Visitante", email: "visitante@example.com", password: "clave-visitante")
    @home = Household.create!(name: "Casa", description: "Hogar compartido")
    @second_home = Household.create!(name: "Segundo hogar")
    @foreign = Household.create!(name: "Hogar privado", description: "Datos privados")
    Membership.create!(user: @user, household: @home, role: "owner")
    Membership.create!(user: @other, household: @home, role: "member")
    Membership.create!(user: @user, household: @second_home, role: "member")
    Membership.create!(user: @outsider, household: @foreign, role: "owner")
    @headers = headers_for(@user)
  end

  test "index and show require valid bearer tokens" do
    [ {}, { "Authorization" => "Bearer invalid" } ].each do |headers|
      [ api_v1_households_url, api_v1_household_url(@home) ].each do |url|
        get url, headers: headers, as: :json

        assert_response :unauthorized
        assert_equal "application/json", response.media_type
        assert response.parsed_body["error"].present?
        assert_no_secrets
      end
    end
  end

  test "index includes only membership households and ignores client user_id" do
    get api_v1_households_url, params: { user_id: @outsider.id }, headers: @headers, as: :json

    assert_response :ok
    assert_equal [
      { "id" => @home.id, "name" => @home.name, "description" => @home.description },
      { "id" => @second_home.id, "name" => @second_home.name, "description" => nil }
    ], response.parsed_body
    assert_not_includes response.body, @foreign.name
    assert_no_secrets
  end

  test "index returns an empty array when user has no memberships" do
    @user.memberships.destroy_all
    get api_v1_households_url, headers: @headers, as: :json

    assert_response :ok
    assert_equal [], response.parsed_body
    assert_no_secrets
  end

  test "show includes only public household and member fields with membership roles" do
    get api_v1_household_url(@home), headers: @headers, as: :json

    assert_response :ok
    assert_equal({
      "id" => @home.id, "name" => @home.name, "description" => @home.description,
      "members" => [
        { "id" => @user.id, "name" => @user.name, "email" => @user.email, "role" => "owner" },
        { "id" => @other.id, "name" => @other.name, "email" => @other.email, "role" => "member" }
      ]
    }, response.parsed_body)
    assert_not_includes response.body, @outsider.email
    assert_no_secrets
  end

  test "member can consult the household without being its owner" do
    get api_v1_household_url(@home), headers: headers_for(@other), as: :json

    assert_response :ok
    assert_equal @home.id, response.parsed_body["id"]
    assert_no_secrets
  end

  test "foreign and nonexistent households return the same error ignoring client user_id" do
    [ @foreign.id, Household.maximum(:id) + 1 ].each do |id|
      get api_v1_household_url(id), params: { user_id: @outsider.id }, headers: @headers, as: :json

      assert_response :not_found
      assert_equal({ "errors" => [ "Hogar no encontrado." ] }, response.parsed_body)
      assert_not_includes response.body, @foreign.name
      assert_not_includes response.body, @outsider.email
      assert_no_secrets
    end
  end

  test "admin role does not bypass household membership" do
    get api_v1_household_url(@foreign), headers: headers_for(@other), as: :json

    assert_response :not_found
    assert_equal({ "errors" => [ "Hogar no encontrado." ] }, response.parsed_body)
    get api_v1_households_url, headers: headers_for(@other), as: :json
    assert_response :ok
    assert_equal [ @home.id ], response.parsed_body.map { |household| household["id"] }
  end

  test "removing membership removes access with the same bearer token" do
    @user.memberships.find_by!(household: @home).destroy!
    get api_v1_household_url(@home), headers: @headers, as: :json

    assert_response :not_found
    assert_no_secrets
  end

  private

  def headers_for(user)
    { "Authorization" => "Bearer #{user.signed_id(purpose: :api_v1)}" }
  end

  def assert_no_secrets
    assert_equal "application/json", response.media_type
    %w[password password_digest token tokens].each { |key| assert_not_includes response.body, key }
    [ @user, @other, @outsider ].each do |user|
      assert_not_includes response.body, user.password
      assert_not_includes response.body, user.password_digest
    end
  end
end
