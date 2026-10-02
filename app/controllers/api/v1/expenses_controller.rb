class Api::V1::ExpensesController < Api::V1::BaseController
  before_action :set_expense, only: %i[show update destroy]

  def index
    expenses = @current_user.expenses.includes(:category, :household, :receipt_attachment)
    expenses = expenses.where(date: filter_date(:from)..) if params[:from].present?
    expenses = expenses.where(date: ..filter_date(:to)) if params[:to].present?
    expenses = expenses.where(category_id: params[:category_id]) if params[:category_id].present?
    expenses = expenses.where(household_id: params[:household_id]) if params[:household_id].present?

    render json: expenses.order(date: :desc, id: :desc).map { |expense| expense_json(expense) }
  rescue Date::Error, TypeError
    render json: { errors: [ "Los filtros from y to deben ser fechas válidas (YYYY-MM-DD)." ] }, status: :bad_request
  end

  def show
    render json: expense_json(@expense)
  end

  def create
    @expense = @current_user.expenses.build(expense_params)
    save_expense(:created)
  end

  def update
    @expense.assign_attributes(expense_params)
    save_expense(:ok)
  end

  def destroy
    @expense.destroy!
    head :no_content
  end

  private

  def set_expense
    @expense = @current_user.expenses.find_by(id: params[:id])
    render json: { errors: [ "Gasto no encontrado." ] }, status: :not_found unless @expense
  end

  def expense_params
    params.permit(:description, :amount, :date, :category_id, :household_id, :notes)
  end

  def filter_date(key)
    Date.iso8601(params[key])
  end

  def save_expense(status)
    if @expense.household_id.present? && (@expense.new_record? || @expense.household_id_changed?) &&
        !@current_user.memberships.exists?(household_id: @expense.household_id)
      render json: { errors: [ "Debes pertenecer al hogar seleccionado." ] }, status: :unprocessable_entity
    elsif @expense.save
      render json: expense_json(@expense), status: status
    else
      render json: { errors: @expense.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def expense_json(expense)
    expense.as_json(only: %i[id description amount date notes]).merge(
      "receipt_attached" => expense.receipt.attached?,
      "category" => expense.category.as_json(only: %i[id name]),
      "household" => expense.household&.as_json(only: %i[id name])
    )
  end
end
