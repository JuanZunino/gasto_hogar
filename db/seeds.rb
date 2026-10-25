# Hold the catalog lock before checking existence so concurrent writers use the
# same serialization mechanism as Category saves. A private name conflict raises
# RecordInvalid and rolls back every category created by this seed run.
Category.transaction do
  Category.lock_catalog!
  Category.uncached do
    Category::DEFAULT_NAMES.each do |name|
      next if Category.global.where("#{Category::NORMALIZED_NAME_SQL} = lower(?)", name).exists?

      Category.create!(name: name)
    end
  end
end
