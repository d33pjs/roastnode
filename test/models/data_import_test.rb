require "test_helper"

class DataImportTest < ActiveSupport::TestCase
  test "records import batch summary and raw payload" do
    import = DataImport.create!(
      workspace: workspaces(:household),
      user: users(:one),
      source: "beanconqueror",
      status: "completed",
      summary: { "beans" => { "created" => 1 } },
      warnings: [ "Skipped unsupported brew abc" ],
      raw_payload: { "BEANS" => [ { "name" => "Imported" } ] }
    )

    assert_equal "beanconqueror", import.source
    assert_equal "completed", import.status
    assert_equal 1, import.summary.dig("beans", "created")
    assert_equal [ "Skipped unsupported brew abc" ], import.warnings
  end

  test "source ids are unique per workspace and record type" do
    attributes = {
      workspace: workspaces(:household),
      name: "Imported Bean",
      bag_size_grams: 250,
      remaining_grams: 250,
      import_source: "beanconqueror",
      import_source_id: "bean-uuid"
    }
    Bean.create!(attributes)

    duplicate = Bean.new(attributes.merge(name: "Duplicate Bean"))

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:import_source_id], "has already been taken"
  end
end
