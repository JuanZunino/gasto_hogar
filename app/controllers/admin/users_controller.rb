class Admin::UsersController < ApplicationController
  before_action :set_user, only: %i[show edit update destroy]

  def index
    @users = User.order(:name)
  end

  def show
  end

  def new
    @user = User.new
  end

  def edit
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to admin_user_path(@user), notice: "Usuario creado correctamente.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attributes = update_user_params
    @user.assign_attributes(attributes)

    if attributes[:password].blank? && attributes[:password_confirmation].present?
      @user.valid?
      @user.errors.add(:password, :blank)
      render :edit, status: :unprocessable_entity
    elsif @user.save
      redirect_to admin_user_path(@user), notice: "Usuario actualizado correctamente.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user.destroy
      redirect_to admin_users_path, notice: "Usuario eliminado correctamente.", status: :see_other
    else
      redirect_to admin_user_path(@user),
        alert: "No se pudo eliminar el usuario porque tiene gastos asociados.", status: :see_other
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def update_user_params
    attributes = user_params
    if attributes[:password].blank? && attributes[:password_confirmation].blank?
      attributes.except(:password, :password_confirmation)
    else
      attributes
    end
  end

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end
end
