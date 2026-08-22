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
    assert_predicate brew.machine, :preinfusion_enabled?
    assert_not_predicate brew.machine, :low_flow_start_enabled?
    assert_not_predicate brew.machine, :flow_control_enabled?
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
    imported_bean = workspace.beans.find_by!(import_source: "beanconqueror", import_source_id: "bc-bean-1")
    share = create_public_bean_share(imported_bean, user: users(:one))
    share.update_columns(snapshot: share.snapshot.merge("no_op_marker" => "untouched"))

    assert_no_difference -> { workspace.beans.count } do
      assert_no_difference -> { workspace.brews.count } do
        import = BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
        assert_equal 1, import.summary.dig("beans", "skipped")
        assert_equal 2, import.summary.dig("brews", "skipped")
      end
    end
    assert_equal "untouched", share.reload.snapshot["no_op_marker"]
  end

  test "later import refreshes public comparison snapshots for an existing imported bean" do
    workspace = workspaces(:household)
    BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
    imported_bean = workspace.beans.find_by!(import_source: "beanconqueror", import_source_id: "bc-bean-1")
    imported_share = create_public_bean_share(imported_bean, user: users(:one))
    peer_share = create_public_bean_share(beans(:open_household), user: users(:one))
    other_workspace_share = create_public_bean_share(beans(:other_workspace_open), user: users(:two))
    other_workspace_share.update_columns(snapshot: other_workspace_share.snapshot.merge("import_marker" => "untouched"))

    assert_equal 1, imported_share.snapshot.dig("stats", "brew_count")
    assert_equal 1, peer_share.snapshot.dig("comparisons", "average_rating", "rank")

    payload = JSON.parse(beanconqueror_json)
    later_brew = payload.fetch("BREWS").first.deep_dup
    later_brew.fetch("config")["uuid"] = "bc-brew-2"
    later_brew.fetch("config")["unix_timestamp"] = 1_777_777_200
    later_brew["rating"] = 5
    payload.fetch("BREWS") << later_brew

    import = BeanconquerorImport.new(workspace:, user: users(:one), json: JSON.generate(payload)).call

    assert_predicate import, :completed?
    assert_equal 1, import.summary.dig("brews", "created")
    assert_equal 2, imported_share.reload.snapshot.dig("stats", "brew_count")
    assert_equal 2, peer_share.reload.snapshot.dig("comparisons", "average_rating", "rank")
    assert_equal "untouched", other_workspace_share.reload.snapshot["import_marker"]
  end

  test "invalid json records failed import" do
    import = BeanconquerorImport.new(workspace: workspaces(:household), user: users(:one), json: "{ nope").call

    assert_predicate import, :failed?
    assert_match "Invalid JSON", import.warnings.first
  end

  test "completed import emits one safe summary and historical brew events" do
    json = file_fixture("beanconqueror_export.json").read

    assert_difference -> { ActivityEvent.where(action: "data_import.completed").count }, 1 do
      @data_import = BeanconquerorImport.new(
        workspace: workspaces(:household), user: users(:one), json:
      ).call
    end

    event = ActivityEvent.where(action: "data_import.completed", subject: @data_import).last
    assert_equal @data_import.summary.values.sum { |part| part.fetch("created", 0) }, event.metadata.fetch("created_count")
    assert_equal @data_import.summary.values.sum { |part| part.fetch("skipped", 0) }, event.metadata.fetch("skipped_count")
    imported_brew = @data_import.brews.first!
    brew_event = ActivityEvent.find_by!(action: "brew.created", subject: imported_brew)
    assert_equal imported_brew.occurred_at, brew_event.occurred_at
    assert_no_match(/warning|raw_payload|uuid|note/i, event.metadata.to_json)
  end

  test "failed import logs status without raw parser error" do
    data_import = BeanconquerorImport.new(
      workspace: workspaces(:household), user: users(:one), json: "{token=secret"
    ).call

    event = ActivityEvent.find_by!(action: "data_import.failed", subject: data_import)
    assert_equal({ "source" => "beanconqueror" }, event.metadata.slice("source"))
    assert_no_match(/token|secret|parser|warning|\{/i, event.metadata.values.join(" "))
  end

  test "activity persistence failure propagates instead of counting an imported Brew as skipped" do
    workspace = workspaces(:household)
    counts = lambda do
      [ DataImport.count, workspace.beans.count, workspace.equipment.count,
        workspace.preparation_tools.count, workspace.brews.count,
        InventoryAdjustment.where(workspace:).count, ActivityEvent.count ]
    end
    before_counts = counts.call
    original_record = Activity::Emitter.method(:record!)
    failing_record = lambda do |**attributes|
      if attributes.fetch(:action) == "brew.created"
        raise ActiveRecord::RecordInvalid.new(ActivityEvent.new)
      end

      original_record.call(**attributes)
    end

    with_stubbed_singleton_method(Activity::Emitter, :record!, failing_record) do
      error = assert_raises(ActiveRecord::RecordInvalid) do
        BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
      end
      assert_instance_of ActivityEvent, error.record
    end

    assert_equal before_counts, counts.call
    assert_not workspace.brews.exists?(import_source: "beanconqueror", import_source_id: "bc-brew-1")
  end

  test "public comparison refresh failure rolls back import rows activity and snapshots" do
    workspace = workspaces(:household)
    share = create_public_bean_share(beans(:open_household), user: users(:one))
    original_snapshot = share.snapshot.deep_dup
    counts = lambda do
      [ DataImport.count, workspace.beans.count, workspace.equipment.count,
        workspace.preparation_tools.count, workspace.brews.count,
        InventoryAdjustment.where(workspace:).count, ActivityEvent.count ]
    end
    before_counts = counts.call
    failing_refresh = lambda do |_workspace|
      share.update!(snapshot: share.snapshot.merge("rollback_marker" => true))
      raise "comparison refresh failed"
    end

    with_stubbed_singleton_method(PublicBeanShareRefresher, :refresh_comparisons_for, failing_refresh) do
      assert_raises(RuntimeError) do
        BeanconquerorImport.new(workspace:, user: users(:one), json: beanconqueror_json).call
      end
    end

    assert_equal before_counts, counts.call
    assert_equal original_snapshot, share.reload.snapshot
    assert_not workspace.beans.exists?(import_source: "beanconqueror", import_source_id: "bc-bean-1")
    assert_not workspace.brews.exists?(import_source: "beanconqueror", import_source_id: "bc-brew-1")
  end

  test "invalid bean url does not skip imported bean" do
    workspace = workspaces(:household)
    payload = JSON.parse(beanconqueror_json)
    payload.fetch("BEANS").first["url"] = "example.com/beans/bc-espresso"

    assert_difference -> { workspace.beans.count }, 1 do
      import = BeanconquerorImport.new(workspace:, user: users(:one), json: JSON.generate(payload)).call

      assert_predicate import, :completed?
      assert_equal 1, import.summary.dig("beans", "created")
      assert_equal 0, import.summary.dig("beans", "skipped")
    end

    bean = workspace.beans.find_by!(import_source: "beanconqueror", import_source_id: "bc-bean-1")
    assert_nil bean.purchase_url
  end

  private
    def create_public_bean_share(bean, user:)
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: user,
        updated_by: user,
        enabled: true,
        title: "Shared bean",
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end

    def beanconqueror_json
      Rails.root.join("test/fixtures/files/beanconqueror_export.json").read
    end
end
