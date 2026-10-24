class Api::V1::CategoriesController < Api::V1::BaseController
  def index
    render json: Category.visible_to(@current_user).order(:name, :id).as_json(only: %i[id name description])
  end
end
