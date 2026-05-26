require "test_helper"

class BeanconquerorImportTest < ActiveSupport::TestCase
  test "imports supported Beanconqueror records" do
    workspace = workspaces(:household)

    assert_difference -> { DataImport.count }, 1 do
      assert_difference -> { workspace.beans.count }, 1 do
        assert_difference -> { workspace.equipment.count }, 2 do
          assert_difference -> { workspace.preparation_tools.count }, 1 do
            assert_difference -> { workspace.brews.count }, 1 do
              assert_difference -> { InventoryAdjustment.count }, 1 do
                import = BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
                assert_predicate import, :completed?
                assert_equal 1, import.summary.dig("beans", "created")
                assert_equal 1, import.summary.dig("brews", "created")
                assert_equal 1, import.summary.dig("brews", "skipped")
                assert_match "Unsupported brew", import.warnings.first
              end
            end
          end
        end
      end
    end

    bean = workspace.beans.find_by!(import_source: "beanconqueror", import_source_id: "bc-bean-1")
    assert_equal "BC Espresso", bean.name
    assert_equal "BC Roaster", bean.roaster_name
    assert_equal "Colombia, Huila", bean.origin
    assert_equal "washed", bean.process
    assert_equal "espresso", bean.roast_type
    assert_equal 3.5.to_d, bean.roast_degree
    assert_equal "single_origin", bean.blend_type
    assert_predicate bean, :decaffeinated?
    assert_equal "Colombia", bean.country
    assert_equal "Huila", bean.region
    assert_equal "La Esperanza", bean.farm
    assert_equal "Ana Gomez", bean.farmer
    assert_equal "1,700 masl", bean.elevation
    assert_equal "Caturra", bean.variety
    assert_equal "2025", bean.harvested
    assert_equal "100%", bean.blend_percentage
    assert_equal 1290, bean.purchase_price_cents
    assert_equal 231.5.to_d, bean.remaining_grams
    assert_equal "Imported bean note.", bean.notes
    assert_equal "BC Espresso", bean.raw_import_data.fetch("name")

    brew = workspace.brews.find_by!(import_source: "beanconqueror", import_source_id: "bc-brew-1")
    assert_equal bean, brew.bean
    assert_equal "BC Grinder", brew.grinder.name
    assert_equal "BC Espresso Machine", brew.machine.name
    assert_equal 18.5.to_d, brew.bean_weight_grams
    assert_equal 18.3.to_d, brew.ground_weight_grams
    assert_equal 42.to_d, brew.beverage_grams
    assert_equal "14", brew.grind_setting
    assert_equal 31, brew.total_time_seconds
    assert_equal [ "BC WDT" ], brew.brew_preparation_tools.order(:position).pluck(:tool_name)
  end

  test "reimport skips existing source ids" do
    workspace = workspaces(:household)

    BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call

    assert_no_difference -> { workspace.beans.count } do
      assert_no_difference -> { workspace.brews.count } do
        import = BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
        assert_equal 1, import.summary.dig("beans", "skipped")
        assert_equal 2, import.summary.dig("brews", "skipped")
      end
    end
  end

  test "invalid json records failed import" do
    import = BeanconquerorImport.new(workspace: workspaces(:household), user: users(:one), json: "{ nope").call

    assert_predicate import, :failed?
    assert_match "Invalid JSON", import.warnings.first
  end

  private
    def beanconqueror_json
      Rails.root.join("test/fixtures/files/beanconqueror_export.json").read
    end
end
