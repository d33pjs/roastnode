class ShortenGeneratedPublicBrewShareTitles < ActiveRecord::Migration[8.1]
  class MigrationPublicBrewShare < ApplicationRecord
    self.table_name = "public_brew_shares"

    belongs_to :brew, class_name: "ShortenGeneratedPublicBrewShareTitles::MigrationBrew"
  end

  class MigrationBrew < ApplicationRecord
    self.table_name = "brews"

    belongs_to :bean, class_name: "ShortenGeneratedPublicBrewShareTitles::MigrationBean"
  end

  class MigrationBean < ApplicationRecord
    self.table_name = "beans"

    def display_name
      [ roaster_name, name ].compact_blank.join(" - ")
    end
  end

  def up
    MigrationPublicBrewShare.includes(brew: :bean).find_each do |share|
      brew = share.brew
      bean = brew.bean
      new_title = generated_title(brew, bean.name)
      old_title = generated_title(brew, bean.display_name)
      next unless share.title == old_title

      snapshot = share.snapshot.is_a?(Hash) ? share.snapshot.deep_dup : {}
      snapshot["title"] = new_title if snapshot["title"] == old_title

      share.update_columns(title: new_title, snapshot:, updated_at: Time.current)
    end
  end

  def down
    # Generated titles are intentionally kept in their shorter current form.
  end

  private
    def generated_title(brew, bean_name)
      "#{brew.method.to_s.humanize} with #{bean_name}"
    end
end
