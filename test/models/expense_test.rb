require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    @category = Category.create!(name: "Alimentos")
    @household = Household.create!(name: "Casa")
    @expense = Expense.new(description: "Compra", amount: "123.45", date: Date.new(2026, 9, 16),
      user: @user, category: @category)
  end

  test "persists a personal expense without a household" do
    @expense.save!

    assert_nil @expense.reload.household
    assert_equal @user, @expense.user
    assert_equal @category, @expense.category
    assert_includes @user.expenses, @expense
    assert_includes @category.expenses, @expense
  end

  test "persists a household expense and its associations" do
    @expense.household = @household
    @expense.save!

    assert_equal @household, @expense.reload.household
    assert_includes @household.expenses, @expense
    assert_includes @user.expenses, @expense
    assert_includes @category.expenses, @expense
  end

  test "requires a nonblank description" do
    [ nil, "", "   " ].each do |description|
      @expense.description = description

      assert_not @expense.valid?
      assert @expense.errors.added?(:description, :blank)
    end
  end

  test "requires an amount" do
    [ nil, "" ].each do |amount|
      @expense.amount = amount

      assert_not @expense.valid?
      assert @expense.errors.added?(:amount, :blank)
    end
  end

  test "requires a numeric amount" do
    @expense.amount = "no es un numero"

    assert_not @expense.valid?
    assert @expense.errors.of_kind?(:amount, :not_a_number)
  end

  test "requires an amount greater than zero" do
    [ "0", "-0.01", "-100" ].each do |amount|
      @expense.amount = amount

      assert_not @expense.valid?
      assert @expense.errors.of_kind?(:amount, :greater_than)
    end
  end

  test "persists monetary amounts with two decimal places" do
    [ "0.01", "123.45", "9999999999.99" ].each do |amount|
      @expense.amount = amount
      @expense.save!

      assert_equal BigDecimal(amount), @expense.reload.amount
    end
  end

  test "requires a date" do
    @expense.date = nil

    assert_not @expense.valid?
    assert @expense.errors.added?(:date, :blank)
  end

  test "requires a user and a category" do
    %i[user category].each do |association|
      expense = @expense.dup
      expense.public_send("#{association}=", nil)

      assert_not expense.valid?
      assert expense.errors.of_kind?(association, :blank)
    end
  end

  test "allows optional notes" do
    [ nil, "", "Compra semanal" ].each do |notes|
      @expense.notes = notes

      assert @expense.valid?
    end
  end

  test "prevents destroying related records and preserves expenses and memberships" do
    membership = Membership.create!(user: @user, household: @household)
    @expense.household = @household
    @expense.save!

    [ @user, @category, @household ].each do |record|
      assert_no_difference [ "Expense.count", "Membership.count" ] do
        assert_equal false, record.destroy
      end

      assert record.errors.of_kind?(:base, :"restrict_dependent_destroy.has_many")
      assert record.class.exists?(record.id)
      assert Membership.exists?(membership.id)
      assert_equal @user.id, @expense.reload.user_id
      assert_equal @category.id, @expense.category_id
      assert_equal @household.id, @expense.household_id
    end
  end

  test "allows destroying related records without expenses" do
    [ @user, @category, @household ].each do |record|
      record.destroy!

      assert_not record.class.exists?(record.id)
    end
  end

  test "foreign keys prevent deleting related records without callbacks" do
    @expense.household = @household
    @expense.save!

    [ @user, @category, @household ].each do |record|
      assert_raises(ActiveRecord::InvalidForeignKey) do
        Expense.transaction(requires_new: true) { record.delete }
      end
    end

    assert Expense.exists?(@expense.id)
  end

  test "database requires user and category references" do
    %i[user category].each do |association|
      expense = @expense.dup
      expense.public_send("#{association}=", nil)

      assert_raises(ActiveRecord::NotNullViolation) do
        Expense.transaction(requires_new: true) { expense.save!(validate: false) }
      end
    end
  end
end
