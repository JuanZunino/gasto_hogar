class Api::V1::SessionsController < Api::V1::BaseController
  skip_before_action :authenticate_user, only: :create

  def create
    email = params[:email]
    password = params[:password]
    user = User.find_by(email: email) if email.is_a?(String)

    if password.is_a?(String) && user&.authenticate(password)
      token = user.signed_id(purpose: TOKEN_PURPOSE, expires_in: 24.hours)
      render json: { token: token, user: user_json(user) }, status: :ok
    else
      render json: { error: "Email o contraseña incorrectos." }, status: :unauthorized
    end
  end
end
