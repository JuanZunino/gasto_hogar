require "test_helper"
require "timeout"

class CategoryConcurrencyTest < ActiveSupport::TestCase
  # Independent connections must see committed records, not fixture transactions.
  self.use_transactional_tests = false

  test "concurrent global and private saves cannot both commit the same visible name" do
    token = SecureRandom.hex(8)
    name = "Concurrent #{token}"
    user = with_bounded_connection do
      User.create!(name: "Concurrent", email: "#{token}@example.com", password: "clave-segura")
    end
    ready = Queue.new
    release = Queue.new
    threads = [ nil, user.id ].map do |owner_id|
      Thread.new do
        with_bounded_connection do
          category = Category.new(name: name, user_id: owner_id)
          checks = 0
          # Both initial validations must pass before either save takes the lock.
          category.define_singleton_method(:name_is_unique_in_visible_catalog) do
            super()
            checks += 1
            if checks == 1
              ready << true
              Timeout.timeout(10) { release.pop }
            end
          end
          saved = Category.cache { category.save }
          [ saved, category.errors.of_kind?(:name, :taken) ]
        end
      end
    end

    Timeout.timeout(10) { 2.times { ready.pop } }
    2.times { release << true }
    results = Timeout.timeout(10) { threads.map(&:value) }

    assert_equal 1, results.count { |saved, _| saved }
    assert_equal 1, results.count { |saved, taken| !saved && taken }
    with_bounded_connection do
      assert_equal 1, Category.where(name: name).count
    end
  ensure
    # Release/join workers before removing only this test's committed records.
    2.times { release << true } if release
    worker_error = nil
    threads&.each do |thread|
      begin
        raise Timeout::Error, "El hilo no terminó dentro del límite de limpieza" unless thread.join(30)
      rescue StandardError => error
        worker_error ||= error
      end
    end
    # Never delete records while a worker could still be using them.
    unless threads&.any?(&:alive?)
      with_bounded_connection do
        Category.where(name: name).delete_all if name
        user&.destroy!
      end
    end
    raise worker_error if worker_error
  end

  private

  def with_bounded_connection
    Timeout.timeout(15) do
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        begin
          connection.transaction(requires_new: true) do
            connection.execute("SET LOCAL lock_timeout = '2s'")
            connection.execute("SET LOCAL statement_timeout = '5s'")
            yield
          end
        ensure
          # Close even after an interrupted query; never return it active to the pool.
          connection.disconnect!
        end
      end
    end
  end
end
