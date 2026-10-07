class Admin::MembershipsController < Admin::BaseController
  before_action :set_membership, only: %i[show edit update destroy]
  before_action :load_form_options, only: %i[new edit create update]

  def index
    @memberships = Membership.includes(:user, :household).order(:id)
  end

  def show
  end

  def new
    @membership = Membership.new
  end

  def edit
  end

  def create
    @membership = Membership.new(membership_params)
    assign_role

    if @membership.save
      redirect_to admin_membership_path(@membership), notice: "Integrante agregado correctamente.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @membership.assign_attributes(membership_params)
    assign_role

    if @membership.save
      redirect_to admin_membership_path(@membership), notice: "Pertenencia actualizada correctamente.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @membership.destroy!
    redirect_to admin_memberships_path, notice: "Pertenencia eliminada correctamente.", status: :see_other
  end

  private

  def set_membership
    @membership = Membership.find(params[:id])
  end

  def load_form_options
    @users = User.order(:name)
    @households = Household.order(:name)
  end

  def membership_params
    params.require(:membership).permit(:user_id, :household_id)
  end

  def assign_role
    attributes = params.require(:membership)
    return unless attributes.key?(:role)

    role = attributes[:role]
    return if role.is_a?(Array) || role.is_a?(ActionController::Parameters)

    # The model validates the explicitly assigned role before saving.
    @membership.role = role
  end
end
