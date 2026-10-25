class Api::V1::CategoriesController < Api::V1::BaseController
  def index
    render json: Category.visible_to(@current_user).order(:name, :id).as_json(only: %i[id name description])
  end

  def create
    category = @current_user.categories.build(params.permit(:name, :description))

    if category.save
      render json: category.as_json(only: %i[id name description]), status: :created
    else
      render json: { errors: category.errors.full_messages }, status: :unprocessable_entity
    end
  end
end
