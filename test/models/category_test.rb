require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "is valid with a name and description" do
    category = Category.new(name: "Alimentos", description: "Compras de comida")

    assert category.valid?
  end

  test "requires a nonblank name" do
    [ nil, "", "   " ].each do |name|
      category = Category.new(name: name)

      assert_not category.valid?
      assert category.errors.added?(:name, :blank)
    end
  end

  test "requires a unique name" do
    Category.create!(name: "Alimentos")
    category = Category.new(name: "Alimentos")

    assert_not category.valid?
    assert category.errors.added?(:name, :taken, value: "Alimentos")
  end

  test "allows distinct names" do
    Category.create!(name: "Alimentos")

    assert Category.new(name: "Transporte").valid?
  end

  test "allows an optional description" do
    [ nil, "" ].each do |description|
      category = Category.new(name: "Alimentos", description: description)

      assert category.valid?
    end
  end

  test "allows updating a category without changing its name" do
    category = Category.create!(name: "Alimentos")

    assert category.update(description: "Compras del supermercado")
  end
end
