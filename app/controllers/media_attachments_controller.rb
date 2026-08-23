class MediaAttachmentsController < ApplicationController
  include SafeImageMedia

  THUMBNAIL_VARIANT = "thumbnail"
  THUMBNAIL_TRANSFORMATIONS = { resize_to_limit: [ 480, 480 ] }.freeze
  HERO_VARIANT = "hero"
  HERO_TRANSFORMATIONS = { resize_to_limit: [ 1200, 1200 ] }.freeze
  MEDIA_VARIANTS = {
    THUMBNAIL_VARIANT => THUMBNAIL_TRANSFORMATIONS,
    HERO_VARIANT => HERO_TRANSFORMATIONS
  }.freeze
  MEDIA_ACTIVITY_ACTIONS = {
    "Bean" => "bean.media_updated",
    "Brew" => "brew.media_updated",
    "ExternalCoffee" => "external_coffee.media_updated",
    "Recipe" => "recipe.media_updated",
    "Equipment" => "equipment.media_updated",
    "PreparationTool" => "preparation_tool.media_updated",
    "EquipmentEvent" => "equipment_event.media_updated",
    "Workspace" => "workspace.media_updated",
    "User" => "profile.media_updated"
  }.freeze

  before_action :set_attachment
  before_action :ensure_attachment_in_current_workspace!
  before_action :ensure_safe_image_attachment!, only: %i[show download primary]

  def show
    return send_blob(disposition: "inline") if params[:variant].blank?

    transformations = MEDIA_VARIANTS[params[:variant]]
    return head :not_found unless transformations

    send_variant(params[:variant], transformations)
  end

  def download
    send_blob(disposition: "attachment")
  end

  def crop
    return unless ensure_write_policy!
    return head :not_found unless photo_collection_record?(@attachment.record)
    return redirect_to record_path(@attachment.record), alert: t(".not_image") unless safe_image_attachment? && @attachment.blob.image?

    save_crop if request.patch?
  end

  def primary
    return unless ensure_write_policy!

    record = @attachment.record
    return head :not_found unless record.respond_to?(:set_primary_photo!)

    record.transaction do
      record.set_primary_photo!(@attachment)
      refresh_public_shares_for(record)
      record_media_activity!(record)
    end

    redirect_back_or_to record_path(record), notice: t(".updated")
  end

  def destroy
    return unless ensure_write_policy!

    record = @attachment.record
    record.transaction do
      @attachment.destroy!
      refresh_public_shares_for(record)
      record_media_activity!(record)
    end

    redirect_back_or_to record_path(record), notice: t(".destroyed")
  end

  private
    def set_attachment
      @attachment = ActiveStorage::Attachment.find(params[:id])
    end

    def send_blob(disposition:, filename: @attachment.blob.filename.to_s, data: @attachment.blob.download)
      send_data data,
        type: safe_image_content_type,
        disposition:,
        filename:
    end

    def send_variant(name, transformations)
      return head :not_found unless safe_image_attachment? && @attachment.blob.image?

      data = variant_data(transformations, name)
      return head :not_found if data.nil?

      response.set_header("X-Roastnode-Media-Variant", name)
      send_blob(
        disposition: "inline",
        filename: "#{name}-#{@attachment.blob.filename}",
        data:
      )
    end

    def variant_data(transformations, name)
      @attachment.blob.variant(transformations).processed.download
    rescue LoadError => error
      variant_failure_data(name, error)
    rescue => error
      variant_failure_data(name, error)
    end

    def variant_failure_data(name, error)
      log_variant_failure(name, error)
      return if name == HERO_VARIANT

      @attachment.blob.download
    end

    def log_variant_failure(name, error)
      Rails.logger.info(
        "Media variant processing failed variant=#{name} error=#{error.class} request_id=#{request.request_id}"
      )
    end

    def ensure_attachment_in_current_workspace!
      head :not_found unless attachment_in_current_workspace?(@attachment)
    end

    def ensure_write_policy!
      return true if attachment_writable?(@attachment)

      redirect_to root_path, alert: t("authorization.denied")
      false
    end

    def save_crop
      attributes = crop_params
      file = attributes[:file]

      unless SafeImageMedia::SAFE_IMAGE_CONTENT_TYPES.include?(file&.content_type.to_s.downcase)
        redirect_to crop_media_attachment_path(@attachment), alert: t(".invalid_image")
        return
      end

      record = @attachment.record
      overwrite = attributes[:mode] == "overwrite"
      make_primary = attributes[:primary] == "1"
      was_primary = record.primary_photo_attachment == @attachment
      new_attachment = nil

      record.transaction do
        record.photos.attach(file)
        new_attachment = record.photos.attachments.max_by(&:id)
        @attachment.destroy! if overwrite
        record.set_primary_photo!(new_attachment) if make_primary || (overwrite && was_primary)
        refresh_public_shares_for(record)
        record_media_activity!(record)
      end

      notice_key = overwrite ? ".updated" : ".created"
      redirect_to record_path(record), notice: t(notice_key)
    end

    def crop_params
      params.expect(crop: [ :file, :mode, :primary ])
    end

    def attachment_in_current_workspace?(attachment)
      record = attachment.record

      case record
      when User
        user_attachment_accessible?(record)
      when Workspace
        record.id == current_workspace&.id
      else
        record.respond_to?(:workspace_id) && record.workspace_id == current_workspace&.id
      end
    end

    def attachment_writable?(attachment)
      record = attachment.record

      case record
      when User
        record.id == Current.user&.id
      when Workspace
        record.id == current_workspace&.id && current_workspace_policy.manage?
      when Equipment, PreparationTool
        current_workspace_policy.manage?
      else
        current_workspace_policy.write?
      end
    end

    def user_attachment_accessible?(user)
      return false unless Current.user && current_workspace
      return true if user.id == Current.user.id

      user.memberships.exists?(workspace_id: current_workspace.id)
    end

    def photo_collection_record?(record)
      record.respond_to?(:photos) && record.respond_to?(:primary_photo_attachment)
    end

    def record_path(record)
      case record
      when Bean
        bean_path(record)
      when Brew
        brew_path(record)
      when ExternalCoffee
        external_coffee_path(record)
      when Recipe
        recipe_path(record)
      when Equipment
        equipment_path(record)
      when PreparationTool
        preparation_tool_path(record)
      when EquipmentEvent
        equipment_event_path(record)
      when User
        edit_profile_path
      when Workspace
        edit_workspace_path
      else
        root_path
      end
    end

    def refresh_public_shares_for(record)
      PublicBrewShareRefresher.refresh_for(record)
      PublicBeanShareRefresher.refresh_for(record)
    end

    def record_media_activity!(record)
      action = MEDIA_ACTIVITY_ACTIONS.fetch(record.class.base_class.name)
      Activity::Emitter.record!(
        action:, workspace: current_workspace, actor: Current.user, subject: record
      )
    end
end
