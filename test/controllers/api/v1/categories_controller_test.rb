require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-ana")
    @transport = Category.create!(name: "Transporte", description: "Viajes")
    @food = Category.create!(name: "Alimentos", description: "Compras de comida")
    @other = User.create!(name: "Luis", email: "luis@example.com", password: "clave-luis")
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "clave-admin", role: "admin")
    @private = @user.categories.create!(name: "Viaje a Japón")
    @foreign = @other.categories.create!(name: "Viaje a Japón", description: "Privada de Luis")
    @admin_private = @admin.categories.create!(name: "Suscripciones", description: "Privada del administrador")
    @headers = { "Authorization" => "Bearer #{@user.signed_id(purpose: :api_v1)}" }
  end

  test "requires a valid bearer token" do
    [ {}, { "Authorization" => "Bearer invalid" } ].each do |headers|
      get api_v1_categories_url, headers: headers, as: :json

      assert_response :unauthorized
      assert_equal "application/json", response.media_type
      assert response.parsed_body["error"].present?
    end
  end

  test "returns global categories for every authenticated user" do
    [ @user, @other, @admin ].each do |user|
      headers = { "Authorization" => "Bearer #{user.signed_id(purpose: :api_v1)}" }
      get api_v1_categories_url, headers: headers, as: :json

      assert_response :ok
      ids = response.parsed_body.map { |category| category.fetch("id") }
      assert_includes ids, @food.id
      assert_includes ids, @transport.id
    end
  end

  test "returns owned private categories" do
    get api_v1_categories_url, headers: @headers, as: :json

    assert_response :ok
    assert_includes response.parsed_body,
      { "id" => @private.id, "name" => "Viaje a Japón", "description" => nil }
  end

  test "does not expose foreign private categories even with a supplied user_id" do
    get api_v1_categories_url, params: { user_id: @other.id }, headers: @headers, as: :json

    assert_response :ok
    ids = response.parsed_body.map { |category| category.fetch("id") }
    assert_equal [ @food.id, @transport.id, @private.id ], ids
    assert_not_includes ids, @foreign.id
    assert_not_includes ids, @admin_private.id
    assert_not_includes response.body, @foreign.description
    assert_not_includes response.body, @admin_private.description
  end

  test "admin API token only sees global and owned private categories" do
    headers = { "Authorization" => "Bearer #{@admin.signed_id(purpose: :api_v1)}" }
    get api_v1_categories_url, headers: headers, as: :json

    assert_response :ok
    ids = response.parsed_body.map { |category| category.fetch("id") }
    assert_equal [ @food.id, @admin_private.id, @transport.id ], ids
    assert_not_includes ids, @private.id
    assert_not_includes ids, @foreign.id
  end

  test "returns the visible catalog ordered by name with the Angular JSON contract" do
    get api_v1_categories_url, headers: @headers, as: :json

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal [
      { "id" => @food.id, "name" => "Alimentos", "description" => "Compras de comida" },
      { "id" => @transport.id, "name" => "Transporte", "description" => "Viajes" },
      { "id" => @private.id, "name" => "Viaje a Japón", "description" => nil }
    ], response.parsed_body
  end
end
