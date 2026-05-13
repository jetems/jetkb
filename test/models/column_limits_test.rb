require "test_helper"

class ColumnLimitsTest < ActiveSupport::TestCase
  # Database errors for exceeding column limits:
  # - MySQL: ActiveRecord::ValueTooLong
  # - SQLite: ActiveRecord::CheckViolation
  COLUMN_LIMIT_ERRORS = [ ActiveRecord::ValueTooLong, ActiveRecord::CheckViolation ]

  test "account name rejects strings over 255 characters" do
    account = Account.new(name: "a" * 256)
    assert_raises(*COLUMN_LIMIT_ERRORS) { account.save! }
  end

  test "account name accepts strings up to 255 characters" do
    account = Account.new(name: "a" * 255)
    assert account.save
  end

  test "account name accepts 255 emoji characters" do
    account = Account.new(name: "🎉" * 255)
    assert account.save
  end

  test "account name rejects 256 emoji characters" do
    account = Account.new(name: "🎉" * 256)
    assert_raises(*COLUMN_LIMIT_ERRORS) { account.save! }
  end

  # Test text column limits (65535 bytes for TEXT)
  # PG's native `text` type is unlimited, so the byte-size rejection assertions
  # below don't apply — under DATABASE_ADAPTER=postgresql we skip them rather
  # than ship a synthetic CHECK constraint just to satisfy the test.
  test "step content rejects text over 65535 bytes" do
    skip "PG text column has no hard byte limit" if Fizzy.db_adapter.postgresql?
    step = Step.new(content: "a" * 65536, card: cards(:logo))
    assert_raises(*COLUMN_LIMIT_ERRORS) { step.save! }
  end

  test "step content accepts text up to 65535 bytes" do
    step = Step.new(content: "a" * 65535, card: cards(:logo))
    assert step.save
  end

  test "step content counts bytes not characters for text columns" do
    skip "PG text column has no hard byte limit" if Fizzy.db_adapter.postgresql?
    # 20000 emoji = 20000 chars but 80000 bytes (over 65535 limit)
    step = Step.new(content: "🎉" * 20000, card: cards(:logo))
    assert_raises(*COLUMN_LIMIT_ERRORS) { step.save! }
  end

  test "ActionText::RichText name rejects strings over 255 characters" do
    rich_text = ActionText::RichText.new(name: "a" * 256, record: cards(:logo))
    assert_raises(*COLUMN_LIMIT_ERRORS) { rich_text.save! }
  end

  test "ActiveStorage::Blob filename rejects strings over 255 characters" do
    Current.account = accounts(:"37s")
    blob = ActiveStorage::Blob.new(filename: "a" * 256, key: "test-key", byte_size: 0, checksum: "test", service_name: "local")
    assert_raises(*COLUMN_LIMIT_ERRORS) { blob.save! }
  end
end
