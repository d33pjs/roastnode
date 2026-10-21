# Private portability settings deliberately omit bearer capabilities and stored public snapshots.
# Restores create disabled drafts with new tokens, requiring explicit review before republishing.
class BeanCollectionPortability
  COLLECTION_KEYS = %w[title description mode selected_bean_ids excluded_bean_ids representative_bean_ids excluded_history_ids].freeze
  BAG_KEYS = %w[bean_id title selected_photo_attachment_ids public_price_cents public_price_currency public_price_recorded_on].freeze

  def self.export(workspace)
    shares = workspace.public_bean_shares.includes(:bean).to_a
    collection = workspace.public_bean_collection
    settings = if collection
      ids_to_beans = shares.index_by(&:id).transform_values(&:bean_id)
      { title: collection.title, description: collection.description, mode: collection.mode,
        selected_bean_ids: collection.selected_share_ids.filter_map { |id| ids_to_beans[id] },
        excluded_bean_ids: collection.excluded_share_ids.filter_map { |id| ids_to_beans[id] },
        representative_bean_ids: collection.representative_share_ids.filter_map { |id| ids_to_beans[id] },
        excluded_history_ids: collection.excluded_history_ids }
    end
    bags = shares.map do |share|
      { bean_id: share.bean_id, title: share.title, selected_photo_attachment_ids: share.valid_selected_photo_attachment_ids,
        public_price_cents: share.public_price_cents, public_price_currency: share.public_price_currency,
        public_price_recorded_on: share.public_price_recorded_on&.iso8601 }
    end
    { public_bean_collection: settings, public_bean_settings: bags }
  end

  def self.valid?(workspace_payload, media_files: [])
    collection = workspace_payload["public_bean_collection"]
    bags = workspace_payload.fetch("public_bean_settings", [])
    return false unless bags.is_a?(Array)
    beans = Array(workspace_payload["beans"]).select { |row| row.is_a?(Hash) }.index_by { |row| row["id"] }
    seen = Set.new
    return false unless bags.all? do |row|
      next false unless row.is_a?(Hash) && row.keys.sort == BAG_KEYS.sort
      bean = beans[row["bean_id"]]
      next false unless bean && seen.add?(row["bean_id"])
      next false unless row["title"].nil? || row["title"].is_a?(String)
      photos = Array(media_files).filter_map do |photo|
        photo["attachment_id"] if photo.is_a?(Hash) && photo["record_type"] == "Bean" &&
          photo["record_id"] == row["bean_id"] && photo["attachment_name"] == "photos"
      end
      next false unless integer_subset?(row["selected_photo_attachment_ids"], photos)
      cents = row["public_price_cents"]
      next true if cents.nil?
      cents.is_a?(Integer) && cents.between?(0, 2_000_000_000) && row["public_price_currency"].is_a?(String) &&
        row["public_price_currency"].match?(/\A[A-Z]{3}\z/) && valid_date?(row["public_price_recorded_on"])
    end
    return true if collection.nil?
    return false unless collection.is_a?(Hash) && collection.keys.sort == COLLECTION_KEYS.sort
    return false unless collection["title"].is_a?(String) && collection["title"].present? && collection["title"].size <= 160
    return false unless collection["description"].nil? || (collection["description"].is_a?(String) && collection["description"].size <= 3000)
    return false unless %w[selected automatic].include?(collection["mode"])
    ids = bags.map { |row| row["bean_id"] }
    histories = Array(workspace_payload["coffee_histories"]).filter_map { |row| row["id"] if row.is_a?(Hash) }
    %w[selected_bean_ids excluded_bean_ids representative_bean_ids].all? { |key| integer_subset?(collection[key], ids) } &&
      integer_subset?(collection["excluded_history_ids"], histories)
  end

  def self.restore(workspace:, payload:, beans:, histories:, attachments:)
    return unless payload["public_bean_collection"] || Array(payload["public_bean_settings"]).any?
    owner = workspace.memberships.find_by!(role: "owner").user
    shares = {}
    PublicBeanCollection.defer_refreshes do
      Array(payload["public_bean_settings"]).each do |row|
        bean = beans.fetch(row.fetch("bean_id"))
        raise InstanceBackupRestorer::RestoreError, "Foreign public bag settings" unless bean.workspace == workspace
        photo_ids = row["selected_photo_attachment_ids"].map do |id|
          attachment = attachments.fetch(id)
          unless attachment.record == bean && attachment.name == "photos"
            raise InstanceBackupRestorer::RestoreError, "Foreign public bag photo settings"
          end
          attachment.id
        end
        share = bean.build_public_bean_share(workspace:, created_by: owner, updated_by: owner, enabled: false,
          title: row["title"], public_price_cents: row["public_price_cents"], public_price_currency: row["public_price_currency"],
          public_price_recorded_on: row["public_price_recorded_on"])
        share.selected_photo_attachment_ids = photo_ids
        share.snapshot = PublicBeanShareSnapshotBuilder.new(bean:, title: share.title,
          selected_photo_attachment_ids: photo_ids, public_price: share.public_price_payload).call
        share.save!(context: :portability_restore)
        shares[row["bean_id"]] = share.id
      end
      if (row = payload["public_bean_collection"])
        workspace.create_public_bean_collection!(title: row["title"], description: row["description"], mode: row["mode"], enabled: false,
          selected_share_ids: row["selected_bean_ids"].map { |id| shares.fetch(id) },
          excluded_share_ids: row["excluded_bean_ids"].map { |id| shares.fetch(id) },
          representative_share_ids: row["representative_bean_ids"].map { |id| shares.fetch(id) },
          excluded_history_ids: row["excluded_history_ids"].map { |id| histories.fetch([ workspace.id, id ]) })
      end
    end
  end

  def self.integer_subset?(values, allowed)
    values.is_a?(Array) && values.all? { |value| value.is_a?(Integer) && allowed.include?(value) } && values.uniq == values
  end

  def self.valid_date?(value)
    value.is_a?(String) && Date.iso8601(value).iso8601 == value
  rescue ArgumentError
    false
  end
end
