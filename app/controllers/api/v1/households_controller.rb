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

    members = household.memberships.includes(:user).order(:id).map do |membership|
      membership.user.as_json(only: %i[id name email]).merge("role" => membership.role)
    end

    render json: household.as_json(only: %i[id name description]).merge("members" => members)
  end
end
