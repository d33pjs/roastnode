module Activity
  module EventContract
    ACTIONS = {
      "coffee" => %w[
        brew.created brew.updated brew.taste_changed brew.serving_changed brew.deleted brew.media_updated
        external_coffee.created external_coffee.updated external_coffee.deleted external_coffee.media_updated
      ],
      "beans_inventory" => %w[
        bean.created bean.updated bean.duplicated bean.opened bean.finished bean.used_up bean.archived bean.reopened
        bean.deleted bean.media_updated inventory_adjustment.created
      ],
      "gear_maintenance" => %w[
        equipment.created equipment.updated equipment.archived equipment.reopened equipment.deleted equipment.media_updated
        preparation_tool.created preparation_tool.updated preparation_tool.archived preparation_tool.reopened
        preparation_tool.deleted preparation_tool.media_updated equipment_event.created equipment_event.updated
        equipment_event.deleted equipment_event.media_updated
      ],
      "sharing_recipes" => %w[
        recipe.created recipe.imported recipe.updated recipe.exported recipe.deleted recipe.media_updated
        public_brew_share.created public_brew_share.published public_brew_share.updated public_brew_share.disabled public_brew_share.deleted
        public_bean_share.created public_bean_share.published public_bean_share.updated public_bean_share.disabled public_bean_share.deleted
        public_recipe_share.created public_recipe_share.published public_recipe_share.updated public_recipe_share.disabled public_recipe_share.deleted
      ],
      "household_administration" => %w[
        workspace.created workspace.updated workspace.media_updated workspace.deleted
        workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
        membership.role_changed membership.removed membership.ownership_transferred
        household_invite.created household_invite.accepted household_invite.revoked household_invite.resent household_invite.reinvited
      ],
      "system_security" => %w[
        profile.updated profile.media_updated password.changed password.reset
        passkey.created passkey.renamed passkey.deleted passkey.second_factor_enabled passkey.second_factor_disabled
        session.signed_in session.signed_out data_import.completed data_import.failed workspace_export.generated
        instance_backup_profile.created instance_backup_profile.updated instance_backup_run.queued
        instance_backup_run.succeeded instance_backup_run.failed instance.first_user_created
      ]
    }.freeze

    WORKSPACE_ADMIN_ACTIONS = %w[
      workspace.created workspace.updated workspace.media_updated
      workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
      membership.role_changed membership.removed membership.ownership_transferred household_invite.accepted
      profile.updated profile.media_updated password.changed password.reset
      passkey.created passkey.renamed passkey.deleted passkey.second_factor_enabled passkey.second_factor_disabled
      session.signed_in session.signed_out data_import.completed data_import.failed workspace_export.generated
    ].freeze

    INSTANCE_ADMIN_ACTIONS = %w[
      workspace.deleted household_invite.created household_invite.revoked household_invite.resent household_invite.reinvited
      instance_backup_profile.created instance_backup_profile.updated instance_backup_run.queued
      instance_backup_run.succeeded instance_backup_run.failed instance.first_user_created
    ].freeze

    ACCOUNT_ACTIONS = %w[
      profile.updated profile.media_updated password.changed password.reset
      passkey.created passkey.renamed passkey.deleted passkey.second_factor_enabled passkey.second_factor_disabled
      session.signed_in session.signed_out
    ].freeze

    SUBJECT_TYPES_BY_PREFIX = {
      "brew" => "Brew", "external_coffee" => "ExternalCoffee", "bean" => "Bean",
      "inventory_adjustment" => "InventoryAdjustment", "equipment" => "Equipment",
      "preparation_tool" => "PreparationTool", "equipment_event" => "EquipmentEvent", "recipe" => "Recipe",
      "public_brew_share" => "PublicBrewShare", "public_bean_share" => "PublicBeanShare",
      "public_recipe_share" => "PublicRecipeShare", "workspace" => "Workspace",
      "workspace_invite" => "WorkspaceInvite", "membership" => "Membership",
      "household_invite" => "HouseholdInvite", "profile" => "User", "password" => "User",
      "passkey" => "PasskeyCredential", "session" => "User", "data_import" => "DataImport",
      "workspace_export" => "Workspace", "instance_backup_profile" => "InstanceBackupProfile",
      "instance_backup_run" => "InstanceBackupRun", "instance" => "User"
    }.freeze

    SUBJECT_TYPE_OVERRIDES = {
      "passkey.second_factor_enabled" => "User",
      "passkey.second_factor_disabled" => "User"
    }.freeze

    ICONS_BY_SUFFIX = {
      "created" => "inventory_2", "updated" => "edit", "deleted" => "delete", "media_updated" => "photo",
      "archived" => "archive", "reopened" => "refresh", "published" => "public", "disabled" => "visibility_off",
      "imported" => "upload_file", "exported" => "file_download", "accepted" => "check_circle",
      "revoked" => "link_off", "resent" => "ios_share", "reinvited" => "refresh", "signed_in" => "login",
      "signed_out" => "logout", "queued" => "backup", "succeeded" => "check_circle", "failed" => "backup"
    }.freeze

    ICON_OVERRIDES = {
      "brew.created" => "local_cafe", "brew.taste_changed" => "local_cafe", "brew.serving_changed" => "group",
      "external_coffee.created" => "local_cafe", "bean.duplicated" => "content_copy", "bean.opened" => "inventory_2",
      "bean.finished" => "check_circle", "bean.used_up" => "check_circle", "inventory_adjustment.created" => "scale",
      "equipment.created" => "build", "preparation_tool.created" => "build", "equipment_event.created" => "build",
      "recipe.created" => "bookmark_add", "public_brew_share.created" => "ios_share",
      "public_bean_share.created" => "ios_share", "public_recipe_share.created" => "ios_share",
      "public_brew_share.deleted" => "link_off", "public_bean_share.deleted" => "link_off", "public_recipe_share.deleted" => "link_off",
      "workspace.created" => "group", "workspace_invite.created" => "group", "membership.role_changed" => "group",
      "membership.ownership_transferred" => "group", "household_invite.created" => "group",
      "password.changed" => "key", "password.reset" => "key", "passkey.created" => "key",
      "passkey.second_factor_enabled" => "security", "passkey.second_factor_disabled" => "security",
      "data_import.completed" => "upload_file", "data_import.failed" => "upload_file",
      "workspace_export.generated" => "file_download", "instance.first_user_created" => "security"
    }.freeze

    SUMMARY_OVERRIDES = {
      "brew.created" => "logged", "brew.updated" => "corrected", "brew.taste_changed" => "taste_changed",
      "brew.serving_changed" => "serving_changed", "external_coffee.created" => "logged",
      "external_coffee.updated" => "corrected", "bean.duplicated" => "duplicated", "bean.opened" => "opened",
      "bean.finished" => "finished", "bean.used_up" => "used_up", "inventory_adjustment.created" => "adjusted",
      "equipment_event.created" => "maintenance_logged", "equipment_event.updated" => "maintenance_corrected",
      "recipe.imported" => "imported", "recipe.exported" => "exported", "membership.role_changed" => "role_changed",
      "membership.removed" => "member_removed", "membership.ownership_transferred" => "ownership_transferred",
      "password.changed" => "password_changed", "password.reset" => "password_reset",
      "passkey.created" => "passkey_added", "passkey.renamed" => "passkey_renamed", "passkey.deleted" => "passkey_removed",
      "passkey.second_factor_enabled" => "second_factor_enabled", "passkey.second_factor_disabled" => "second_factor_disabled",
      "session.signed_in" => "signed_in", "session.signed_out" => "signed_out",
      "data_import.completed" => "import_completed", "data_import.failed" => "import_failed",
      "workspace_export.generated" => "export_generated", "instance_backup_run.queued" => "backup_queued",
      "instance_backup_run.succeeded" => "backup_succeeded", "instance_backup_run.failed" => "backup_failed",
      "instance.first_user_created" => "first_user_created"
    }.freeze

    DETAIL_KEYS = {
      "bean.duplicated" => %w[source_label], "membership.role_changed" => %w[from_role to_role],
      "membership.ownership_transferred" => %w[from_role to_role], "workspace_export.generated" => %w[export_kind],
      "session.signed_in" => %w[authentication_method], "data_import.completed" => %w[source created_count skipped_count],
      "data_import.failed" => %w[source], "instance_backup_profile.created" => %w[backup_kind],
      "instance_backup_profile.updated" => %w[backup_kind], "instance_backup_run.queued" => %w[backup_kind status],
      "instance_backup_run.succeeded" => %w[backup_kind status file_size_bytes],
      "instance_backup_run.failed" => %w[backup_kind status]
    }.freeze

    BASE_REQUIRED_METADATA_KEYS = %w[actor_kind actor_label].freeze
    REQUIRED_METADATA_KEYS = {
      "inventory_adjustment.created" => %w[amount_grams],
      "membership.role_changed" => %w[from_role to_role],
      "data_import.completed" => %w[created_count skipped_count]
    }.freeze

    AUTOMATIC_METADATA_ACTIONS = {
      "method" => %w[brew.created brew.updated brew.taste_changed brew.serving_changed brew.deleted brew.media_updated],
      "status" => %w[
        bean.created bean.updated bean.duplicated bean.opened bean.finished bean.used_up bean.archived bean.reopened
        bean.deleted bean.media_updated instance_backup_run.queued instance_backup_run.succeeded instance_backup_run.failed
      ],
      "amount_grams" => %w[inventory_adjustment.created],
      "event_types" => %w[equipment_event.created equipment_event.updated equipment_event.deleted equipment_event.media_updated],
      "equipment_labels" => %w[equipment_event.created equipment_event.updated equipment_event.deleted equipment_event.media_updated],
      "enabled" => %w[
        public_brew_share.created public_brew_share.published public_brew_share.updated public_brew_share.disabled public_brew_share.deleted
        public_bean_share.created public_bean_share.published public_bean_share.updated public_bean_share.disabled public_bean_share.deleted
        public_recipe_share.created public_recipe_share.published public_recipe_share.updated public_recipe_share.disabled public_recipe_share.deleted
      ],
      "role" => %w[
        workspace_invite.created workspace_invite.accepted workspace_invite.revoked workspace_invite.resent workspace_invite.reinvited
        membership.role_changed membership.removed membership.ownership_transferred
      ],
      "source" => %w[data_import.completed data_import.failed],
      "backup_kind" => %w[
        instance_backup_profile.created instance_backup_profile.updated instance_backup_run.queued
        instance_backup_run.succeeded instance_backup_run.failed
      ],
      "file_size_bytes" => %w[instance_backup_run.succeeded]
    }.freeze

    DETAIL_VALUES = {
      "session.signed_in" => { "authentication_method" => %w[password passkey passkey_second_factor invited_signup] },
      "workspace_export.generated" => { "export_kind" => %w[json beans_csv brews_csv external_coffees_csv media_zip] },
      "data_import.completed" => { "source" => %w[beanconqueror] },
      "data_import.failed" => { "source" => %w[beanconqueror] },
      "instance_backup_profile.created" => { "backup_kind" => %w[full_archive readable_json] },
      "instance_backup_profile.updated" => { "backup_kind" => %w[full_archive readable_json] },
      "instance_backup_run.queued" => { "backup_kind" => %w[full_archive readable_json], "status" => %w[queued] },
      "instance_backup_run.succeeded" => { "backup_kind" => %w[full_archive readable_json], "status" => %w[succeeded] },
      "instance_backup_run.failed" => { "backup_kind" => %w[full_archive readable_json], "status" => %w[failed] }
    }.freeze

    BASE_METADATA_SCHEMA = {
      "actor_kind" => { type: :string, values: %w[user system] },
      "actor_label" => { type: :string },
      "record_kind" => { type: :string },
      "subject_label" => { type: :string }
    }.freeze

    METADATA_KEY_SCHEMAS = {
      "method" => { type: :string, values: %w[espresso quick_drip] },
      "status" => { type: :string, values: %w[stock open finished used_up archived] },
      "amount_grams" => { type: :decimal_string },
      "event_types" => {
        type: :string_array,
        values: %w[
          grinder_cleaning grinder_deep_cleaning machine_descaling machine_backflush brewer_cleaning
          brewer_descaling filter_change burr_change other
        ]
      },
      "equipment_labels" => { type: :string_array },
      "enabled" => { type: :boolean },
      "role" => { type: :string, values: %w[owner admin member viewer] },
      "source" => { type: :string, values: %w[beanconqueror] },
      "backup_kind" => { type: :string, values: %w[full_archive readable_json] },
      "file_size_bytes" => { type: :integer, minimum: 0 },
      "source_label" => { type: :string },
      "from_role" => { type: :string, values: %w[owner admin member viewer] },
      "to_role" => { type: :string, values: %w[owner admin member viewer] },
      "export_kind" => { type: :string, values: %w[json beans_csv brews_csv external_coffees_csv media_zip] },
      "authentication_method" => { type: :string, values: %w[password passkey passkey_second_factor invited_signup] },
      "created_count" => { type: :integer, minimum: 0 },
      "skipped_count" => { type: :integer, minimum: 0 }
    }.freeze

    module_function

    def fetch(action)
      action = action.to_s
      category = ACTIONS.find { |_category, actions| actions.include?(action) }&.first
      raise KeyError, "unknown activity action: #{action}" unless category

      suffix = action.split(".").last
      automatic_metadata_keys = AUTOMATIC_METADATA_ACTIONS.filter_map do |key, actions|
        key if actions.include?(action)
      end
      metadata_keys = (automatic_metadata_keys + DETAIL_KEYS.fetch(action, [])).uniq
      required_metadata_keys = BASE_REQUIRED_METADATA_KEYS + REQUIRED_METADATA_KEYS.fetch(action, [])
      {
        category:,
        visibility: visibility_for(action),
        visibilities: ACCOUNT_ACTIONS.include?(action) ? %w[workspace_admin instance_admin] : [ visibility_for(action) ],
        subject_type: SUBJECT_TYPE_OVERRIDES.fetch(action, SUBJECT_TYPES_BY_PREFIX.fetch(action.split(".").first)),
        icon: ICON_OVERRIDES.fetch(action, ICONS_BY_SUFFIX.fetch(suffix, "more_vert")),
        summary: SUMMARY_OVERRIDES.fetch(action, suffix),
        detail_keys: DETAIL_KEYS.fetch(action, []),
        automatic_metadata_keys:,
        metadata_keys:,
        required_metadata_keys:,
        metadata_schema: BASE_METADATA_SCHEMA.merge(
          metadata_keys.index_with { |key| metadata_schema_for(action, key) }
        ),
        detail_values: DETAIL_VALUES.fetch(action, {})
      }
    end

    def metadata_schema_for(action, key)
      schema = METADATA_KEY_SCHEMAS.fetch(key)
      allowed_values = DETAIL_VALUES.dig(action, key)
      allowed_values ? schema.merge(values: allowed_values) : schema
    end

    def visibility_for(action)
      return "instance_admin" if INSTANCE_ADMIN_ACTIONS.include?(action)
      return "workspace_admin" if WORKSPACE_ADMIN_ACTIONS.include?(action)

      "workspace"
    end

    def actions
      ACTIONS.values.flatten.freeze
    end
  end
end
