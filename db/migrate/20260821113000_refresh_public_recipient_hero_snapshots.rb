class RefreshPublicRecipientHeroSnapshots < ActiveRecord::Migration[8.1]
  def up
    PublicBrewShare.find_each { |share| PublicBrewShareRefresher.refresh(share) }
    PublicBeanShare.find_each { |share| PublicBeanShareRefresher.refresh(share) }
  end

  def down
    # Curated snapshots intentionally stay on the safer current projection.
  end
end
