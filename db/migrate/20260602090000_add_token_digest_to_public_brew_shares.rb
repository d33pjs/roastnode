require "digest"

class AddTokenDigestToPublicBrewShares < ActiveRecord::Migration[8.1]
  Share = Class.new(ActiveRecord::Base) do
    self.table_name = "public_brew_shares"
  end

  def up
    add_column :public_brew_shares, :token_digest, :string

    Share.reset_column_information
    Share.find_each do |share|
      next if share.token.blank?

      share.update_columns(token_digest: Digest::SHA256.hexdigest(share.token))
    end

    change_column_null :public_brew_shares, :token_digest, false
    add_index :public_brew_shares, :token_digest, unique: true
  end

  def down
    remove_index :public_brew_shares, :token_digest
    remove_column :public_brew_shares, :token_digest
  end
end
