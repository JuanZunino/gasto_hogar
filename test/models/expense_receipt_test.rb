require "test_helper"

class ExpenseReceiptTest < ActiveSupport::TestCase
  setup do
    user = User.create!(name: "Ana", email: "ana@example.com", password: "clave-segura")
    category = Category.create!(name: "Alimentos")
    @expense = user.expenses.create!(description: "Compra", amount: 10, date: "2026-10-02", category: category)
  end

  teardown do
    @expense.receipt.purge if @expense.receipt.attached?
  end

  test "receipt is optional" do
    assert @expense.valid?
    assert_not @expense.receipt.attached?
  end

  test "attaches a receipt to the correct expense and preserves it on update" do
    File.open(file_fixture("receipt.pdf")) do |file|
      @expense.receipt.attach(io: file, filename: "receipt.pdf", content_type: "application/pdf")
    end

    assert @expense.reload.receipt.attached?
    assert_equal @expense, @expense.receipt.attachment.record
    assert_equal "application/pdf", @expense.receipt.content_type
    assert_equal File.binread(file_fixture("receipt.pdf")), @expense.receipt.download
    blob_id = @expense.receipt.blob_id
    @expense.update!(notes: "Nota nueva")
    assert_equal blob_id, @expense.reload.receipt.blob_id
    assert_equal 1, @expense.receipt_attachment.class.where(record: @expense, name: "receipt").count
  end
end
