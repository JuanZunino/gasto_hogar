class Api::V1::BaseController < ActionController::API
  TOKEN_PURPOSE = :api_v1

  before_action :authenticate_user

  private

  def authenticate_user
    token = request.authorization.to_s.match(/\ABearer ([^\s]+)\z/i)&.captures&.first
    @current_user = User.find_signed(token, purpose: TOKEN_PURPOSE) if token

    render json: { error: "Token ausente o inválido." }, status: :unauthorized unless @current_user
  end

  def user_json(user)
    user.as_json(only: %i[id name email role])
  end
end
