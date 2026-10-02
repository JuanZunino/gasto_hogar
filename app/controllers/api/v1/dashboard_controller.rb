class Api::V1::DashboardController < Api::V1::BaseController
  def show
    expenses = @current_user.expenses
    expenses = expenses.where(date: Date.iso8601(params[:from])..) if params[:from].present?
    expenses = expenses.where(date: ..Date.iso8601(params[:to])) if params[:to].present?

    category_totals = expenses.joins(:category)
      .group("categories.id", "categories.name")
      .order(Arel.sql("SUM(expenses.amount) DESC"), "categories.id ASC")
      .sum(:amount)

    render json: {
      total_expenses: money(expenses.sum(:amount)),
      expenses_count: expenses.count,
      expenses_by_category: category_totals.map do |(id, name), total|
        { category: { id: id, name: name }, total: money(total) }
      end
    }
  rescue Date::Error, TypeError
    render json: { errors: [ "Los filtros from y to deben ser fechas válidas (YYYY-MM-DD)." ] }, status: :bad_request
  end

  private

  def money(amount)
    whole, fraction = amount.to_d.round(2).to_s("F").split(".")
    "#{whole}.#{fraction.ljust(2, "0")}"
  end
end
