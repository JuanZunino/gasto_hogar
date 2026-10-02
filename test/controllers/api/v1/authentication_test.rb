require "test_helper"

class Api::V1::AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: "Juan Zunino", email: "juan@example.com", password: "12345678", role: "user")
    @admin = User.create!(name: "Admin", email: "admin@example.com", password: "clave-admin", role: "admin")
  end

  test "valid credentials return a token for users and administrators" do
    [ [ @user, "12345678" ], [ @admin, "clave-admin" ] ].each do |user, password|
      post api_v1_login_url, params: { email: user.email, password: password }, as: :json

      assert_response :ok
      assert_equal %w[token user], response.parsed_body.keys.sort
      assert_equal public_attributes(user), response.parsed_body["user"]
      assert_equal user, User.find_signed(response.parsed_body["token"], purpose: :api_v1)
      assert_no_secrets
      assert_nil response.headers["Set-Cookie"]
    end
  end

  [ { email: "incorrecto@example.com", password: "12345678" },
    { email: "juan@example.com", password: "incorrecta" },
    {}, { email: [ "juan@example.com" ], password: "12345678" },
    { email: "juan@example.com", password: { value: "12345678" } } ].each_with_index do |credentials, index|
    test "invalid credentials return a generic error #{index}" do
      post api_v1_login_url, params: credentials, as: :json

      assert_response :unauthorized
      assert_equal({ "error" => "Email o contraseña incorrectos." }, response.parsed_body)
      assert_no_secrets
    end
  end

  test "profile rejects missing invalid and non bearer tokens" do
    token = @user.signed_id(purpose: :api_v1)
    [ nil, "Bearer invalid", "Bearer", "Basic #{token}", "Bearer #{token} extra",
      "Bearer #{token.reverse}", "Bearer #{@user.signed_id(purpose: :other)}" ].each do |authorization|
      get api_v1_profile_url, headers: { "Authorization" => authorization }, as: :json
      assert_unauthorized_profile
    end
  end

  test "profile returns the token owner ignoring client supplied identifiers" do
    post api_v1_login_url, params: { email: @user.email, password: "12345678" }, as: :json
    token = response.parsed_body.fetch("token")
    get api_v1_profile_url, params: { user_id: @admin.id }, headers: { "Authorization" => "Bearer #{token}" }, as: :json

    assert_response :ok
    assert_equal public_attributes(@user), response.parsed_body
    assert_no_secrets
  end

  test "login token expires after 24 hours" do
    post api_v1_login_url, params: { email: @user.email, password: "12345678" }, as: :json
    token = response.parsed_body.fetch("token")

    travel 24.hours + 1.second do
      get api_v1_profile_url, headers: { "Authorization" => "Bearer #{token}" }, as: :json
      assert_unauthorized_profile
    end
  end

  test "deleted user's token is rejected" do
    token = @user.signed_id(purpose: :api_v1)
    @user.destroy!
    get api_v1_profile_url, headers: { "Authorization" => "Bearer #{token}" }, as: :json
    assert_unauthorized_profile
  end

  test "admin session does not authenticate API and survives API requests" do
    post admin_login_url, params: { email: @admin.email, password: "clave-admin" }
    get api_v1_profile_url, as: :json
    assert_unauthorized_profile

    post api_v1_login_url, params: { email: @user.email, password: "12345678" }, as: :json
    assert_response :ok
    post api_v1_login_url, params: { email: @user.email, password: "incorrecta" }, as: :json
    assert_response :unauthorized

    get admin_users_url
    assert_response :ok
    assert_equal @admin.id, session[:admin_user_id]
  end

  test "API login does not create an admin session" do
    post api_v1_login_url, params: { email: @admin.email, password: "clave-admin" }, as: :json
    token = response.parsed_body.fetch("token")
    get admin_users_url, headers: { "Authorization" => "Bearer #{token}" }
    assert_redirected_to admin_login_url
  end

  private

  def public_attributes(user)
    { "id" => user.id, "name" => user.name, "email" => user.email, "role" => user.role }
  end

  def assert_no_secrets
    assert_equal "application/json", response.media_type
    %w[password password_digest].each { |key| assert_not_includes response.body, key }
    [ @user, @admin ].each do |user|
      assert_not_includes response.body, user.password_digest
      assert_not_includes response.body, user.password
    end
  end

  def assert_unauthorized_profile
    assert_response :unauthorized
    assert_equal({ "error" => "Token ausente o inválido." }, response.parsed_body)
    assert_no_secrets
  end
end
