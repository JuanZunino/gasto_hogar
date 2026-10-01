class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: %i[show edit update destroy]

  def index
    @categories = Category.order(:name)
  end

  def show
  end

  def new
    @category = Category.new
  end

  def edit
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to admin_category_path(@category), notice: "Categoría creada correctamente.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @category.update(category_params)
      redirect_to admin_category_path(@category), notice: "Categoría actualizada correctamente.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.destroy
      redirect_to admin_categories_path, notice: "Categoría eliminada correctamente.", status: :see_other
    else
      redirect_to admin_category_path(@category),
        alert: "No se pudo eliminar la categoría porque tiene gastos asociados.", status: :see_other
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description)
  end
end
