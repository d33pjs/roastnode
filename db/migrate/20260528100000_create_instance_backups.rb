class CreateInstanceBackups < ActiveRecord::Migration[8.1]
  def change
    create_table :instance_backup_profiles do |t|
      t.string :name, null: false
      t.string :backup_kind, null: false
      t.boolean :enabled, null: false, default: false
      t.string :schedule, null: false, default: "manual"
      t.string :storage_path, null: false, default: "storage/instance_backups"
      t.integer :retention_count, null: false, default: 7
      t.datetime :last_enqueued_at

      t.timestamps
    end

    add_index :instance_backup_profiles, :backup_kind
    add_index :instance_backup_profiles, [ :enabled, :schedule ]

    create_table :instance_backup_runs do |t|
      t.references :instance_backup_profile, null: false, foreign_key: true
      t.string :backup_kind, null: false
      t.string :status, null: false, default: "queued"
      t.datetime :started_at
      t.datetime :finished_at
      t.string :file_path
      t.bigint :file_size_bytes
      t.string :checksum_sha256
      t.text :error_message

      t.timestamps
    end

    add_index :instance_backup_runs, [ :instance_backup_profile_id, :status ]
    add_index :instance_backup_runs, :created_at
  end
end
