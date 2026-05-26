class AddImportMetadataToDomainRecords < ActiveRecord::Migration[8.1]
  def change
    add_import_metadata :beans
    add_import_metadata :equipment
    add_import_metadata :preparation_tools
    add_import_metadata :brews
  end

  private
    def add_import_metadata(table)
      add_reference table, :data_import, foreign_key: true
      add_column table, :import_source, :string
      add_column table, :import_source_id, :string
      add_column table, :raw_import_data, :jsonb, null: false, default: {}
      add_index table, [ :workspace_id, :import_source, :import_source_id ],
        unique: true,
        where: "import_source IS NOT NULL AND import_source_id IS NOT NULL",
        name: "idx_#{table}_import_identity"
    end
end
