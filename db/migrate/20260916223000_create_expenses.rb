class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.string :description, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :date, null: false
      t.text :notes
      t.references :user, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :household, null: true, foreign_key: true

      t.timestamps
    end
  end
end
