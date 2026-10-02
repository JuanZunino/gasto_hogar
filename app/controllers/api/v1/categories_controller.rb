class Api::V1::CategoriesController < Api::V1::BaseController
  def index
    render json: Category.order(:name).as_json(only: %i[id name description])
  end
end
