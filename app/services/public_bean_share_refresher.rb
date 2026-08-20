class PublicBeanShareRefresher
  class << self
    def refresh(share)
      new(share).refresh
    end

    def refresh_for(record)
      shares_for(record).find_each { |share| refresh(share) }
    end

    def refresh_comparisons_for(record)
      comparison_shares_for(record).find_each { |share| refresh(share) }
    end

    def shares_for(record)
      case record
      when PublicBeanShare
        PublicBeanShare.where(id: record.id)
      when Bean
        PublicBeanShare.where(bean_id: record.id)
      when Brew
        PublicBeanShare.where(bean_id: record.bean_id)
      when Equipment
        PublicBeanShare
          .joins(bean: :brews)
          .where(
            "brews.grinder_id = :equipment_id OR " \
            "brews.machine_id = :equipment_id OR " \
            "brews.brewer_id = :equipment_id",
            equipment_id: record.id
          )
          .distinct
      when Workspace
        PublicBeanShare.where(workspace_id: record.id)
      when User
        PublicBeanShare.joins(bean: :brews).where(brews: { user_id: record.id }).distinct
      when RecordLink
        record.linkable ? shares_for(record.linkable) : PublicBeanShare.none
      else
        PublicBeanShare.none
      end
    end

    def comparison_shares_for(record)
      workspace_id = record.is_a?(Workspace) ? record.id : record.workspace_id
      return PublicBeanShare.none if workspace_id.blank?

      PublicBeanShare.where(workspace_id:)
    end
  end

  def initialize(share)
    @share = share
  end

  def refresh
    share.reload
    unless share.publishable?
      share.update_columns(enabled: false, updated_at: Time.current)
      return
    end

    selected_photo_attachment_ids = share.valid_selected_photo_attachment_ids
    title = share.title.presence || PublicBeanShare.default_title_for(share.bean)
    snapshot = PublicBeanShareSnapshotBuilder.new(
      bean: share.bean,
      title:,
      selected_photo_attachment_ids:
    ).call

    share.update!(
      title:,
      selected_photo_attachment_ids:,
      snapshot:
    )
  end

  private
    attr_reader :share
end
