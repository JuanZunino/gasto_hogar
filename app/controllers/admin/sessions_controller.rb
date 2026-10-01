class Admin::SessionsController < Admin::BaseController
  skip_before_action :require_admin, only: %i[new create]

  def new
  end

  def create
    user = User.find_by(email: params[:email])

    if user&.authenticate(params[:password].to_s) && user.role == "admin"
      reset_session
      session[:admin_user_id] = user.id
      redirect_to admin_users_path, notice: "Sesión iniciada correctamente.", status: :see_other
    else
      reset_session
      flash.now[:alert] = "Email o contraseña incorrectos, o acceso administrativo no autorizado."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to admin_login_path, notice: "Sesión cerrada correctamente.", status: :see_other
  end
end
