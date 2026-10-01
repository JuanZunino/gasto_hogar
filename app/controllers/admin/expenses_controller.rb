class Admin::ExpensesController < Admin::BaseController
  before_action :set_expense, only: %i[show edit update destroy]
  before_action :load_form_options, only: %i[new edit create update]

  def index
    @expenses = Expense.includes(:user, :category, :household).order(date: :desc, id: :desc)
  end

  def show
  end

  def new
    @expense = Expense.new
  end

  def edit
  end

  def create
    @expense = Expense.new(expense_params)

    if @expense.save
      redirect_to admin_expense_path(@expense), notice: "Gasto creado correctamente.", status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @expense.update(expense_params)
      redirect_to admin_expense_path(@expense), notice: "Gasto actualizado correctamente.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy!
    redirect_to admin_expenses_path, notice: "Gasto eliminado correctamente.", status: :see_other
  end

  private

  def set_expense
    @expense = Expense.find(params[:id])
  end

  def load_form_options
    @users = User.order(:name)
    @categories = Category.order(:name)
    @households = Household.order(:name)
  end

  def expense_params
    params.require(:expense).permit(:description, :amount, :date, :notes, :user_id, :category_id, :household_id)
  end
end
