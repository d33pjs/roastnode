class PublicBeanCollectionsController < ApplicationController
  before_action :authorize_workspace_admin!
  before_action :set_collection

  def edit
    load_form_state
  end

  def update
    PublicBeanCollection.transaction do
      PublicBeanCollection.defer_refreshes do
      attributes = collection_params.to_h
      publish_ids = attributes.delete("publish_bean_ids") || []
      validate_share_selections!(attributes)
      preserve_unavailable_selections!(attributes)
      beans = current_workspace.beans.where(id: publish_ids).includes(:public_bean_share, :primary_photo_record, photos_attachments: :blob).to_a
      raise ActiveRecord::RecordNotFound unless beans.size == publish_ids.reject(&:blank?).uniq.size

      new_shares = beans.map { |bean| publish_bag!(bean) }
      if attributes["mode"] == "selected"
        attributes["selected_share_ids"] = Array(attributes["selected_share_ids"]) + new_shares.map(&:id)
      end
      PublicBeanShareRefresher.refresh_for(current_workspace)
      attributes["enabled"] = false if new_shares.any?
      @collection.update!(attributes)
      Activity::Emitter.record!(action: "workspace.updated", workspace: current_workspace, actor: Current.user, subject: current_workspace)
    end
      end
    redirect_to edit_public_bean_collection_path, notice: t("bean_collection_operations.saved")
  rescue ActiveRecord::RecordInvalid => error
    @collection.errors.add(:base, error.record.errors.full_messages.to_sentence) unless error.record == @collection
    load_form_state
    render :edit, status: :unprocessable_entity
  end

  def preview
    @snapshot = @collection.persisted? ? @collection.public_snapshot : PublicBeanCollectionSnapshotBuilder.new(collection: @collection).call
    @preview = true
    prepare_public_view
    render "public_bean_collection_pages/show"
  end

  private
    def set_collection
      @collection = current_workspace.public_bean_collection || current_workspace.build_public_bean_collection(
        title: t("bean_collection_operations.default_title"))
    end

    def collection_params
      params.require(:public_bean_collection).permit(:title, :description, :enabled, :mode,
        selected_share_ids: [], excluded_share_ids: [], representative_share_ids: [], excluded_history_ids: [], publish_bean_ids: [])
    end

    def preserve_unavailable_selections!(attributes)
      unavailable_histories = current_workspace.coffee_histories.where.not(id: @collection.eligible_shares.select("beans.coffee_history_id")).pluck(:id)
      if attributes.key?("excluded_history_ids")
        attributes["excluded_history_ids"] = Array(attributes["excluded_history_ids"]) + (@collection.excluded_history_ids & unavailable_histories)
      end
      unavailable = current_workspace.public_bean_shares.where.not(id: @collection.eligible_shares.select(:id)).pluck(:id)
      %w[selected_share_ids excluded_share_ids representative_share_ids].each do |key|
        next unless attributes.key?(key)

        attributes[key] = Array(attributes[key]) + (@collection[key] & unavailable)
      end
    end

    def validate_share_selections!(attributes)
      histories = Array(attributes["excluded_history_ids"]).reject(&:blank?).uniq
      if histories.any?
        raise ActiveRecord::RecordNotFound unless histories.all? { |id| id.to_s.match?(/\A\d+\z/) }
        raise ActiveRecord::RecordNotFound unless current_workspace.coffee_histories.where(id: histories).count == histories.size
      end
      ids = %w[selected_share_ids excluded_share_ids representative_share_ids].flat_map { |key| Array(attributes[key]) }.reject(&:blank?).uniq
      return if ids.empty?
      raise ActiveRecord::RecordNotFound unless ids.all? { |id| id.to_s.match?(/\A\d+\z/) }
      raise ActiveRecord::RecordNotFound unless current_workspace.public_bean_shares.where(id: ids).count == ids.size
    end

    def publish_bag!(bean)
      raise ActiveRecord::RecordNotFound unless PublicBeanShare.publishable_bean?(bean)
      # Bulk selection never removes an existing password or re-enables a disabled capability.
      if bean.public_bean_share
        raise ActiveRecord::RecordInvalid.new(@collection) unless bean.public_bean_share.enabled? && !bean.public_bean_share.password_protected?
        return bean.public_bean_share
      end
      share = bean.build_public_bean_share(workspace: current_workspace, created_by: Current.user,
        updated_by: Current.user, enabled: true, title: PublicBeanShare.default_title_for(bean))
      photo = bean.primary_photo_attachment
      selected = photo && %w[image/jpeg image/png image/gif image/webp].include?(photo.blob.content_type) ? [ photo.id ] : []
      share.refresh_snapshot!(title: share.title, selected_photo_attachment_ids: selected, updated_by: Current.user)
      Activity::Emitter.record!(action: "public_bean_share.published", workspace: current_workspace, actor: Current.user, subject: share)
      share
    end

    def load_form_state
      @available_shares = @collection.eligible_shares.includes(bean: { photos_attachments: :blob }).order(:created_at).to_a
      @publishable_beans = current_workspace.beans.includes(:public_bean_share).order(:roaster_name, :name).select do |bean|
        PublicBeanShare.publishable_bean?(bean) && bean.public_bean_share.nil?
      end
    end

    def prepare_public_view
      @view = params[:view] == "all" ? "all" : "top"
      all = Array(@snapshot["groups"])
      @total_groups = all.size
      @groups = @view == "all" ? all : all.select { |group| group["rank"] && group["rank"] <= 10 }
    end
end
