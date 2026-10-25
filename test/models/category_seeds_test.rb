require "test_helper"

class CategorySeedsTest < ActiveSupport::TestCase
  test "creates all ten defaults and is idempotent" do
    assert_difference "Category.count", 10 do
      load_seeds
    end
    assert_equal Category::DEFAULT_NAMES.sort, Category.global.pluck(:name).sort
    original = Category.order(:id).map(&:attributes)

    assert_no_difference "Category.count" do
      load_seeds
    end
    assert_equal original, Category.order(:id).map(&:attributes)
  end

  test "preserves existing variants descriptions categories and expense references" do
    category = Category.create!(name: "alimentos", description: "Conservar")
    category.update_columns(name: " \tALIMENTOS\n ")
    user = User.create!(name: "Ana", email: "seeds@example.com", password: "clave-segura")
    common = Category.create!(name: "Viaje")
    private_category = user.categories.create!(name: "Compras")
    expense = Expense.create!(description: "Compra", amount: 10, date: Date.current,
      user: user, category: category)
    originals = [ category, common, private_category, expense ].map { |record| record.reload.attributes }

    assert_difference "Category.count", 9 do
      load_seeds
    end
    assert_equal originals, [ category, common, private_category, expense ].map { |record| record.reload.attributes }
  end

  test "rolls back all creations when a missing default conflicts with a private category" do
    existing = Category.create!(name: "alimentos", description: "Conservar")
    user = User.create!(name: "Ana", email: "conflict@example.com", password: "clave-segura")
    private_category = user.categories.create!(name: " OTROS ")
    original = Category.order(:id).map(&:attributes)

    assert_no_difference "Category.count" do
      error = assert_raises(ActiveRecord::RecordInvalid) { load_seeds }
      assert_equal "Otros", error.record.name
    end
    assert_equal original, Category.order(:id).map(&:attributes)
    assert_equal [ existing.id, private_category.id ].sort, Category.pluck(:id).sort
  end

  private

  def load_seeds
    load Rails.root.join("db/seeds.rb")
  end
end
