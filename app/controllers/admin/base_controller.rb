class Admin::BaseController < ApplicationController
  layout "admin"

  before_action :require_admin
  helper_method :current_admin

  private

  def current_admin
    return @current_admin if defined?(@current_admin)

    @current_admin = User.find_by(id: session[:admin_user_id], role: "admin")
  end

  def require_admin
    return if current_admin

    reset_session
    redirect_to admin_login_path, alert: "Debes iniciar sesión como administrador.", status: :see_other
  end
end
