class MediaAttachmentsController < ApplicationController
  before_action :set_attachment
  before_action :ensure_attachment_in_current_workspace!

  def show
    send_data @attachment.blob.download,
      type: @attachment.blob.content_type,
      disposition: "inline",
      filename: @attachment.blob.filename.to_s
  end

  def download
    send_data @attachment.blob.download,
      type: @attachment.blob.content_type,
      disposition: "attachment",
      filename: @attachment.blob.filename.to_s
  end

  def crop
    return unless ensure_write_policy!
    return head :not_found unless photo_collection_record?(@attachment.record)
    return redirect_to record_path(@attachment.record), alert: t(".not_image") unless @attachment.blob.image?

    save_crop if request.patch?
  end

  def primary
    return unless ensure_write_policy!

    record = @attachment.record
    return head :not_found unless record.respond_to?(:set_primary_photo!)

    record.set_primary_photo!(@attachment)

    redirect_back_or_to record_path(record), notice: t(".updated")
  end

  def destroy
    return unless ensure_write_policy!

    record = @attachment.record
    @attachment.destroy!

    redirect_back_or_to record_path(record), notice: t(".destroyed")
  end

  private
    def set_attachment
      @attachment = ActiveStorage::Attachment.find(params[:id])
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

      unless file&.content_type&.start_with?("image/")
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
      when Equipment
        equipment_path(record)
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
end
