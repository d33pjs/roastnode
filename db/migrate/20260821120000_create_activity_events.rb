class CreateActivityEvents < ActiveRecord::Migration[8.1]
  MAX_TEXT = 160
  MAX_ARRAY = 10
  SENSITIVE = %r{https?://|rails/active_storage|[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}|(?:password|digest|token|secret|session|signed_id|attachment|filename|ip_address|file_path|error)\s*[:=]}i

  class ActivityRow < ActiveRecord::Base
    self.table_name = "activity_events"
  end

  class LegacyUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class LegacyBean < ActiveRecord::Base
    self.table_name = "beans"
  end

  class LegacyBrew < ActiveRecord::Base
    self.table_name = "brews"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
    belongs_to :bean, class_name: "CreateActivityEvents::LegacyBean"
  end

  class LegacyExternalCoffee < ActiveRecord::Base
    self.table_name = "external_coffees"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
  end

  class LegacyInventoryAdjustment < ActiveRecord::Base
    self.table_name = "inventory_adjustments"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
    belongs_to :bean, class_name: "CreateActivityEvents::LegacyBean"
  end

  class LegacyEquipment < ActiveRecord::Base
    self.table_name = "equipment"
  end

  class LegacyEquipmentEventItem < ActiveRecord::Base
    self.table_name = "equipment_event_items"
    belongs_to :equipment, class_name: "CreateActivityEvents::LegacyEquipment"
  end

  class LegacyEquipmentEvent < ActiveRecord::Base
    self.table_name = "equipment_events"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
    has_many :items, class_name: "CreateActivityEvents::LegacyEquipmentEventItem", foreign_key: :equipment_event_id
    has_many :equipment, through: :items
  end

  class LegacyRecipe < ActiveRecord::Base
    self.table_name = "recipes"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyPublicBrewShare < ActiveRecord::Base
    self.table_name = "public_brew_shares"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyPublicBeanShare < ActiveRecord::Base
    self.table_name = "public_bean_shares"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyPublicRecipeShare < ActiveRecord::Base
    self.table_name = "public_recipe_shares"
    belongs_to :creator, class_name: "CreateActivityEvents::LegacyUser", foreign_key: :created_by_id
  end

  class LegacyDataImport < ActiveRecord::Base
    self.table_name = "data_imports"
    belongs_to :user, class_name: "CreateActivityEvents::LegacyUser"
  end

  def up
    create_table :activity_events do |t|
      t.references :workspace, null: true, foreign_key: { on_delete: :cascade }
      t.references :actor, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.string :category, null: false
      t.string :action, null: false
      t.datetime :occurred_at, null: false
      t.string :visibility, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end

    add_index :activity_events, [ :workspace_id, :occurred_at, :id ], name: "idx_activity_workspace_time"
    add_index :activity_events, [ :workspace_id, :category, :occurred_at, :id ], name: "idx_activity_workspace_category_time"
    add_index :activity_events, [ :workspace_id, :actor_id, :occurred_at, :id ], name: "idx_activity_workspace_actor_time"
    add_index :activity_events, [ :visibility, :workspace_id, :occurred_at, :id ], name: "idx_activity_visibility_workspace_time"
    add_index :activity_events, [ :subject_type, :subject_id ], name: "idx_activity_subject"
    add_index :activity_events, [ :occurred_at, :id ], name: "idx_activity_instance_time", where: "workspace_id IS NULL"

    add_check_constraint :activity_events,
      "(visibility = 'instance_admin' AND workspace_id IS NULL) OR " \
        "(visibility IN ('workspace', 'workspace_admin') AND workspace_id IS NOT NULL)",
      name: "activity_events_visibility_scope"
    add_check_constraint :activity_events,
      "(subject_type IS NULL AND subject_id IS NULL) OR (subject_type IS NOT NULL AND subject_id IS NOT NULL)",
      name: "activity_events_subject_pair"

    ActivityRow.reset_column_information
    @migration_time = Time.current
    backfill_brews
    backfill_external_coffees
    backfill_manual_adjustments
    backfill_equipment_events
    backfill_recipes
    backfill_public_shares
    backfill_completed_imports
  end

  def down
    drop_table :activity_events
  end

  private
    attr_reader :migration_time

    def backfill_brews
      insert_each(LegacyBrew.includes(:user, :bean)) do |brew|
        event_row(
          workspace_id: brew.workspace_id,
          actor: brew.user,
          category: "coffee",
          action: "brew.created",
          occurred_at: brew.occurred_at,
          subject_type: "Brew",
          subject_id: brew.id,
          metadata: {
            "record_kind" => "brew",
            "subject_label" => "#{brew.method == "quick_drip" ? "Quick Drip" : "Espresso"} with #{brew.bean.name}",
            "method" => brew.method
          }
        )
      end
    end

    def backfill_external_coffees
      insert_each(LegacyExternalCoffee.includes(:user)) do |coffee|
        event_row(
          workspace_id: coffee.workspace_id,
          actor: coffee.user,
          category: "coffee",
          action: "external_coffee.created",
          occurred_at: coffee.occurred_at,
          subject_type: "ExternalCoffee",
          subject_id: coffee.id,
          metadata: { "record_kind" => "external_coffee", "subject_label" => safe_label(coffee.drink_type) }
        )
      end
    end

    def backfill_manual_adjustments
      insert_each(LegacyInventoryAdjustment.where(reason: "manual").includes(:user, :bean)) do |adjustment|
        event_row(
          workspace_id: adjustment.workspace_id,
          actor: adjustment.user,
          category: "beans_inventory",
          action: "inventory_adjustment.created",
          occurred_at: adjustment.occurred_at,
          subject_type: "InventoryAdjustment",
          subject_id: adjustment.id,
          metadata: {
            "record_kind" => "inventory_adjustment",
            "subject_label" => safe_label(adjustment.bean.name),
            "amount_grams" => adjustment.delta_grams.to_s("F")
          }
        )
      end
    end

    def backfill_equipment_events
      insert_each(LegacyEquipmentEvent.includes(:user, :equipment)) do |event|
        event_types = Array(event.event_types).presence || Array(event.event_type)
        equipment_labels = event.equipment.map { |item| safe_label(item.name) }.sort.first(10)
        event_row(
          workspace_id: event.workspace_id,
          actor: event.user,
          category: "gear_maintenance",
          action: "equipment_event.created",
          occurred_at: event.occurred_at,
          subject_type: "EquipmentEvent",
          subject_id: event.id,
          metadata: {
            "record_kind" => "equipment_event",
            "subject_label" => safe_label(event_types.map(&:humanize).to_sentence),
            "event_types" => event_types.first(10),
            "equipment_labels" => equipment_labels
          }
        )
      end
    end

    def backfill_recipes
      insert_each(LegacyRecipe.includes(:creator)) do |recipe|
        event_row(
          workspace_id: recipe.workspace_id,
          actor: recipe.creator,
          category: "sharing_recipes",
          action: "recipe.created",
          occurred_at: recipe.created_at,
          subject_type: "Recipe",
          subject_id: recipe.id,
          metadata: { "record_kind" => "recipe", "subject_label" => safe_label(recipe.title) }
        )
      end
    end

    def backfill_public_shares
      backfill_share(LegacyPublicBrewShare.includes(:creator), "public_brew_share", "PublicBrewShare")
      backfill_share(LegacyPublicBeanShare.includes(:creator), "public_bean_share", "PublicBeanShare")
      backfill_share(LegacyPublicRecipeShare.includes(:creator), "public_recipe_share", "PublicRecipeShare")
    end

    def backfill_share(scope, kind, subject_type)
      insert_each(scope) do |share|
        event_row(
          workspace_id: share.workspace_id,
          actor: share.creator,
          category: "sharing_recipes",
          action: "#{kind}.created",
          occurred_at: share.created_at,
          subject_type:,
          subject_id: share.id,
          metadata: {
            "record_kind" => kind,
            "subject_label" => safe_label(share.title.presence || kind.humanize),
            "enabled" => share.enabled
          }
        )
      end
    end

    def backfill_completed_imports
      scope = LegacyDataImport.where(status: "completed").where.not(summary: {})
      insert_each(scope.includes(:user)) do |data_import|
        summary = data_import.summary.to_h
        event_row(
          workspace_id: data_import.workspace_id,
          actor: data_import.user,
          category: "system_security",
          action: "data_import.completed",
          occurred_at: data_import.updated_at,
          visibility: "workspace_admin",
          subject_type: "DataImport",
          subject_id: data_import.id,
          metadata: {
            "record_kind" => "data_import",
            "subject_label" => safe_label("#{data_import.source.to_s.humanize} import"),
            "source" => data_import.source.to_s,
            "created_count" => summary_count(summary, "created"),
            "skipped_count" => summary_count(summary, "skipped")
          }
        )
      end
    end

    def summary_count(summary, key)
      summary.values.sum { |value| value.is_a?(Hash) ? value[key].to_i : 0 }
    end

    def insert_each(scope)
      rows = []
      scope.find_each do |record|
        rows << yield(record)
        if rows.size >= 500
          ActivityRow.insert_all!(rows)
          rows.clear
        end
      end
      ActivityRow.insert_all!(rows) if rows.any?
    end

    def event_row(workspace_id:, actor:, category:, action:, occurred_at:, subject_type:, subject_id:, metadata:, visibility: "workspace")
      {
        workspace_id:,
        actor_id: actor&.id,
        category:,
        action:,
        occurred_at:,
        visibility:,
        subject_type:,
        subject_id:,
        metadata: sanitized_metadata(actor_metadata(actor).merge(metadata)),
        created_at: migration_time,
        updated_at: migration_time
      }
    end

    def actor_metadata(actor)
      if actor
        { "actor_kind" => "user", "actor_label" => safe_label(actor.display_name.presence || "unknown username") }
      else
        { "actor_kind" => "system", "actor_label" => "System" }
      end
    end

    def sanitized_metadata(metadata)
      metadata.to_h.transform_values { |value| safe_value(value) }.compact
    end

    def safe_value(value)
      case value
      when String, Symbol then safe_label(value)
      when Numeric, TrueClass, FalseClass, NilClass then value
      when Array then value.first(MAX_ARRAY).map { |item| safe_label(item) }
      else "[redacted]"
      end
    end

    def safe_label(value)
      text = value.to_s.strip.squish
      return "[redacted]" if text.match?(SENSITIVE) || text.start_with?("/", "../")

      text.first(MAX_TEXT).presence || "Unknown"
    end
end
