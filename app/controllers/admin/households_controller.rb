class Admin::HouseholdsController < Admin::BaseController
  before_action :set_household, only: %i[show edit update destroy]

  def index
    @households = Household.order(:name)
  end

  def show
    @memberships = @household.memberships.includes(:user).order(:id)
  end

  def new
    @household = Household.new
  end

  def edit
  end

  def create
    @household = Household.new(household_params)

    if @household.save
      redirect_to admin_household_path(@household), notice: "Hogar creado correctamente.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @household.update(household_params)
      redirect_to admin_household_path(@household), notice: "Hogar actualizado correctamente.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @household.destroy
      redirect_to admin_households_path, notice: "Hogar eliminado correctamente.", status: :see_other
    else
      redirect_to admin_household_path(@household),
        alert: "No se pudo eliminar el hogar porque tiene gastos asociados.", status: :see_other
    end
  end

  private

  def set_household
    @household = Household.find(params[:id])
  end

  def household_params
    params.require(:household).permit(:name, :description)
  end
end
