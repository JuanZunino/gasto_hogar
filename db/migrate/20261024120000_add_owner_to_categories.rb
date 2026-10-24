class AddOwnerToCategories < ActiveRecord::Migration[8.1]
  NORMALIZED_NAME_SQL = "lower(regexp_replace(name, '^[[:space:]]+|[[:space:]]+$', '', 'g'))".freeze

  def up
    # Transaction-local: fail promptly on contention without changing session defaults.
    execute "SET LOCAL lock_timeout = '5s'"
    # Keep the preflight and DDL atomic, excluding concurrent category writers.
    execute "LOCK TABLE categories IN ACCESS EXCLUSIVE MODE"
    conflicts = select_all(<<~SQL).to_a
      SELECT #{NORMALIZED_NAME_SQL} AS normalized_name, array_agg(id ORDER BY id) AS ids
      FROM categories
      GROUP BY #{NORMALIZED_NAME_SQL}
      HAVING count(*) > 1 OR length(#{NORMALIZED_NAME_SQL}) = 0
    SQL
    if conflicts.any?
      raise ActiveRecord::MigrationError, "Categorías incompatibles: #{conflicts.inspect}"
    end

    add_reference :categories, :user, null: true, foreign_key: true
    add_index :categories, NORMALIZED_NAME_SQL, unique: true,
      where: "user_id IS NULL", name: "index_categories_on_global_name"
    add_index :categories, "user_id, #{NORMALIZED_NAME_SQL}", unique: true,
      where: "user_id IS NOT NULL", name: "index_categories_on_private_name"
    remove_index :categories, name: "index_categories_on_name"
  end

  def down
    # Removing ownership would expose private data; never do so implicitly.
    raise ActiveRecord::IrreversibleMigration, "La reversión eliminaría la propiedad de categorías privadas"
  end
end
