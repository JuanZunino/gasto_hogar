require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    @other = User.create!(name: "Luis", email: "luis@example.com", password: "clave-segura")
  end

  test "identifies all defaults only for global categories ignoring case and exterior whitespace" do
    Category::DEFAULT_NAMES.each do |name|
      assert Category.new(name: " \t#{name.upcase}\n ").default?
      assert_not Category.new(name: name, user: @user).default?
    end
    assert_not Category.new(name: "Viaje").default?
  end

  test "prevents default renaming including capitalization changes and skipped validations" do
    category = Category.create!(name: "Alimentos")

    [ "Comida", "ALIMENTOS" ].each do |name|
      assert_not category.update(name: name)
      assert category.errors[:name].present?
      assert_equal "Alimentos", category.reload.name
      category.name = name
      assert_not category.save(validate: false)
      assert_equal "Alimentos", category.reload.name
    end
  end

  test "protects existing default variants and allows description changes" do
    category = Category.create!(name: "alimentos", description: "Original")
    # Simulate a legacy value without invoking normalization callbacks.
    category.update_columns(name: " \tALIMENTOS\n ")
    category.reload

    assert category.default?
    assert_not category.update(name: "Comida")
    category.reload
    # Preserve the legacy name when editing only its description.
    assert category.update(description: "Actualizada")
    assert_equal "Actualizada", category.reload.description
    assert_equal " \tALIMENTOS\n ", category.name
    category.name = "Comida"
    assert_no_difference "Category.count" do
      assert_equal false, category.destroy
    end
    assert category.errors[:base].present?
    assert_raises(ActiveRecord::RecordNotDestroyed) { category.reload.destroy! }
  end

  test "allows renaming and deleting common global and private categories including private defaults" do
    [ Category.create!(name: "Viaje"), @user.categories.create!(name: "Alimentos") ].each do |category|
      assert_not category.default?
      assert category.update(name: "Excursión", description: "Actualizada")
      assert_equal "Actualizada", category.reload.description
      assert_difference "Category.count", -1 do
        category.destroy!
      end
    end
  end

  test "trims exterior spaces preserving readable capitalization" do
    category = Category.create!(name: " \tViaje a Japón\n ", user: @user)

    assert_equal "Viaje a Japón", category.reload.name
  end

  test "scopes include global and only owned private categories" do
    global = Category.create!(name: "Alimentos")
    own = @user.categories.create!(name: "Viaje")
    foreign = @other.categories.create!(name: "Viaje")

    assert_equal [ global.id ], Category.global.pluck(:id)
    assert_equal [ global.id, own.id ].sort, Category.visible_to(@user).pluck(:id).sort
    assert_not_includes Category.visible_to(@user), foreign
  end

  test "rejects case and space variants within the same owner" do
    @user.categories.create!(name: "Viaje a Japón")

    assert_not @user.categories.build(name: "  VIAJE A JAPÓN ").valid?
    assert @other.categories.create!(name: "viaje a japón").persisted?
  end

  test "rejects global private collisions in both directions" do
    Category.create!(name: "Alimentos")
    assert_not @user.categories.build(name: " ALIMENTOS ").valid?

    @other.categories.create!(name: "Viaje")
    assert_not Category.new(name: " VIAJE ").valid?
    assert_not Category.new(name: " alimentos ").valid?
  end

  test "rename checks the visible catalog without rejecting the same record" do
    category = @user.categories.create!(name: "Viaje")
    Category.create!(name: "Alimentos")

    assert category.update(name: " VIAJE ")
    assert_not category.update(name: " ALIMENTOS ")
    assert_equal "VIAJE", category.reload.name
  end

  test "requires an existing user when user_id is supplied" do
    category = Category.new(name: "Viaje", user_id: User.maximum(:id) + 1)

    assert_not category.valid?
    assert category.errors.of_kind?(:user, :blank)
  end

  test "forbids transferring ownership and converting either category type" do
    global = Category.create!(name: "Alimentos")
    private_category = @user.categories.create!(name: "Viaje")

    assert_not global.update(user: @user)
    assert_nil global.reload.user_id
    assert_not private_category.update(user: @other)
    assert_equal @user.id, private_category.reload.user_id
    assert_not private_category.update(user: nil)
    assert_equal @user.id, private_category.reload.user_id
  end

  test "save callbacks still protect ownership and visible uniqueness when validations are skipped" do
    Category.create!(name: "Alimentos")
    category = @user.categories.create!(name: "Viaje")
    category.user = @other

    assert_not category.save(validate: false)
    assert_equal @user.id, category.reload.user_id
    category.name = " ALIMENTOS "
    assert_not category.save(validate: false)
    assert_equal "Viaje", category.reload.name
  end

  test "partial indexes reject normalized duplicates without model callbacks" do
    [ nil, @user.id ].each do |owner_id|
      Category.create!(name: owner_id ? "Viaje" : "Alimentos", user_id: owner_id)
      assert_raises(ActiveRecord::RecordNotUnique) do
        Category.transaction(requires_new: true) do
          Category.insert_all!([ { name: owner_id ? " VIAJE " : " ALIMENTOS ", user_id: owner_id } ])
        end
      end
    end
  end

  test "foreign key rejects a nonexistent owner without model callbacks" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Category.transaction(requires_new: true) do
        Category.insert_all!([ { name: "Viaje", user_id: User.maximum(:id) + 1 } ])
      end
    end
  end

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
