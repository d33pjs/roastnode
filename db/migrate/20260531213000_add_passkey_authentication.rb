class AddPasskeyAuthentication < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :webauthn_user_id, :string
    add_column :users, :passkey_second_factor_enabled, :boolean, default: false, null: false
    add_index :users, :webauthn_user_id, unique: true

    create_table :passkey_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, default: 0, null: false
      t.string :nickname
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :passkey_credentials, :external_id, unique: true
  end
end
