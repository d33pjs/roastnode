class AddMachineExtractionFeatures < ActiveRecord::Migration[8.1]
  def change
    add_column :equipment, :preinfusion_enabled, :boolean, default: false, null: false
    add_column :equipment, :low_flow_start_enabled, :boolean, default: false, null: false
    add_column :equipment, :flow_control_enabled, :boolean, default: false, null: false

    add_column :brews, :low_flow_start_seconds, :integer
    add_column :brews, :flow_control_used, :boolean

    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE equipment
          SET preinfusion_enabled = TRUE
          WHERE kind = 'machine'
        SQL
      end
    end
  end
end
