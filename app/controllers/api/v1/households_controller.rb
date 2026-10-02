class Api::V1::HouseholdsController < Api::V1::BaseController
  def index
    render json: @current_user.households.order(:id).as_json(only: %i[id name description])
  end

  def show
    household = @current_user.households.find_by(id: params[:id])
    unless household
      render json: { errors: [ "Hogar no encontrado." ] }, status: :not_found
      return
    end

    render json: household_json(household)
  end

  def create
    household = Household.new(params.permit(:name, :description))

    Household.transaction do
      household.save!
      household.memberships.create!(user: @current_user, role: "owner")
    end

    render json: household_json(household), status: :created
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => error
    errors = error.record.errors.full_messages.presence || [ "No se pudo crear el hogar." ]
    render json: { errors: errors }, status: :unprocessable_entity
  end

  private

  def household_json(household)
    members = household.memberships.includes(:user).order(:id).map do |membership|
      membership.user.as_json(only: %i[id name email]).merge("role" => membership.role)
    end

    household.as_json(only: %i[id name description]).merge("members" => members)
  end
end
