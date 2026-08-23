class PublicBrewShareRefresher
  class << self
    def refresh(share)
      new(share).refresh
    end

    def refresh_for(record)
      shares_for(record).find_each { |share| refresh(share) }
    end

    def shares_for(record)
      case record
      when PublicBrewShare
        PublicBrewShare.where(id: record.id)
      when Brew
        PublicBrewShare.where(brew_id: record.id)
      when Bean
        PublicBrewShare.joins(:brew).where(brews: { bean_id: record.id })
      when Equipment
        PublicBrewShare
          .joins(:brew)
          .where("brews.grinder_id = :equipment_id OR brews.machine_id = :equipment_id", equipment_id: record.id)
      when PreparationTool
        PublicBrewShare
          .joins(brew: :brew_preparation_tools)
          .where(brew_preparation_tools: { preparation_tool_id: record.id })
          .distinct
      when Workspace
        PublicBrewShare.where(workspace_id: record.id)
      when User
        PublicBrewShare
          .joins(:brew)
          .where(
            "brews.user_id = :user_id OR brews.recipient_user_id = :user_id",
            user_id: record.id
          )
          .distinct
      when RecordLink
        record.linkable ? shares_for(record.linkable) : PublicBrewShare.none
      else
        PublicBrewShare.none
      end
    end
  end

  def initialize(share)
    @share = share
  end

  def refresh
    share.reload
    selected_photo_attachment_ids = share.valid_selected_photo_attachment_ids
    title = PublicBrewShare.normalized_generated_title(share.title, share.brew)
    snapshot = PublicBrewShareSnapshotBuilder.new(
      brew: share.brew,
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
