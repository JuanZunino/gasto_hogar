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

  test "create returns a private category owned by the authenticated user with the GET JSON contract" do
    assert_no_difference "Category.global.count" do
      assert_difference [ "Category.count", "@user.categories.count" ], 1 do
        post api_v1_categories_url, params: { name: "Cursos", description: "Formación" }, headers: @headers, as: :json
      end
    end

    assert_response :created
    assert_equal "application/json", response.media_type
    category = @user.categories.find(response.parsed_body.fetch("id"))
    assert_equal @user.id, category.user_id
    assert_equal({ "id" => category.id, "name" => "Cursos", "description" => "Formación" }, response.parsed_body)
    created_json = response.parsed_body

    get api_v1_categories_url, headers: @headers, as: :json
    assert_response :ok
    assert_includes response.parsed_body, created_json
    other_headers = { "Authorization" => "Bearer #{@other.signed_id(purpose: :api_v1)}" }
    get api_v1_categories_url, headers: other_headers, as: :json
    assert_response :ok
    assert_not_includes response.parsed_body.map { |record| record.fetch("id") }, category.id
  end

  test "create ignores foreign and null ownership parameters" do
    [ @other.id, nil ].each_with_index do |owner_id, index|
      assert_no_difference [ "Category.global.count", "@other.categories.count" ] do
        assert_difference "@user.categories.count", 1 do
          post api_v1_categories_url, params: { name: "Curso #{index}", user_id: owner_id }, headers: @headers, as: :json
        end
      end

      assert_response :created
      category = Category.find(response.parsed_body.fetch("id"))
      assert_equal @user.id, category.user_id
      assert_nil response.parsed_body.fetch("description")
      assert_equal %w[description id name], response.parsed_body.keys.sort
    end
  end

  test "admin creation is private even when requesting a null owner" do
    headers = { "Authorization" => "Bearer #{@admin.signed_id(purpose: :api_v1)}" }

    assert_no_difference "Category.global.count" do
      assert_difference "@admin.categories.count", 1 do
        post api_v1_categories_url, params: { name: "Cursos", user_id: nil }, headers: headers, as: :json
      end
    end

    assert_response :created
    assert_equal @admin.id, Category.find(response.parsed_body.fetch("id")).user_id
  end

  test "create requires a valid bearer token" do
    [ {}, { "Authorization" => "Bearer invalid" } ].each do |headers|
      assert_no_difference "Category.count" do
        post api_v1_categories_url, params: { name: "Cursos" }, headers: headers, as: :json
      end

      assert_response :unauthorized
      assert_equal "application/json", response.media_type
      assert response.parsed_body["error"].present?
    end
  end

  test "create rejects missing empty and whitespace only names" do
    [ {}, { name: nil }, { name: "" }, { name: " \t\n " } ].each do |attributes|
      assert_no_difference "Category.count" do
        post api_v1_categories_url, params: attributes, headers: @headers, as: :json
      end

      assert_creation_errors
    end
  end

  test "create rejects own duplicates including capitalization and exterior spaces" do
    [ "Viaje a Japón", " \tVIAJE A JAPÓN\n " ].each do |name|
      assert_no_difference "Category.count" do
        post api_v1_categories_url, params: { name: name }, headers: @headers, as: :json
      end

      assert_creation_errors
    end
  end

  test "create rejects global collisions including capitalization and exterior spaces" do
    [ "Alimentos", " \tALIMENTOS\n " ].each do |name|
      assert_no_difference "Category.count" do
        post api_v1_categories_url, params: { name: name }, headers: @headers, as: :json
      end

      assert_creation_errors
    end
  end

  test "different users can create homonymous private categories and names are trimmed" do
    ids = [ @user, @other ].map do |user|
      headers = { "Authorization" => "Bearer #{user.signed_id(purpose: :api_v1)}" }
      assert_no_difference "Category.global.count" do
        assert_difference "user.categories.count", 1 do
          post api_v1_categories_url, params: { name: " \tCursos\n " }, headers: headers, as: :json
        end
      end

      assert_response :created
      category = user.categories.find(response.parsed_body.fetch("id"))
      assert_equal "Cursos", category.name
      assert_equal "Cursos", response.parsed_body.fetch("name")
      category.id
    end

    assert_equal 2, ids.uniq.size
  end

  test "category routes expose only index and create" do
    assert_routing({ path: "/api/v1/categories", method: :get },
      { controller: "api/v1/categories", action: "index" })
    assert_routing({ path: "/api/v1/categories", method: :post },
      { controller: "api/v1/categories", action: "create" })

    [ :get, :patch, :put, :delete ].each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("/api/v1/categories/#{@private.id}", method: method)
      end
    end
    [ "/api/v1/categories/new", "/api/v1/categories/#{@private.id}/edit" ].each do |path|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(path, method: :get)
      end
    end
  end

  private

  def assert_creation_errors
    assert_response :unprocessable_entity
    assert_equal "application/json", response.media_type
    assert_equal [ "errors" ], response.parsed_body.keys
    assert_kind_of Array, response.parsed_body.fetch("errors")
    assert_not_empty response.parsed_body.fetch("errors")
    assert response.parsed_body.fetch("errors").all? { |message| message.is_a?(String) }
  end
end
