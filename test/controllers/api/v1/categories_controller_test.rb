require "test_helper"

class Api::V1::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-ana")
    @transport = Category.create!(name: "Transporte", description: "Viajes")
    @food = Category.create!(name: "Alimentos", description: "Compras de comida")
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

  test "returns the general catalog ordered by name with only public attributes" do
    get api_v1_categories_url, headers: @headers, as: :json

    assert_response :ok
    assert_equal "application/json", response.media_type
    assert_equal [
      { "id" => @food.id, "name" => "Alimentos", "description" => "Compras de comida" },
      { "id" => @transport.id, "name" => "Transporte", "description" => "Viajes" }
    ], response.parsed_body
  end
end
