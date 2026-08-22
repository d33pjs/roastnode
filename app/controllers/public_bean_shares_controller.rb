class PublicBeanSharesController < ApplicationController
  before_action :set_bean
  before_action :ensure_publishable_bean!, only: %i[new create edit update]
  before_action :set_or_build_share
  before_action :authorize_share_management!

  def new
    load_form_state(default_selected_photo_attachment_ids)
  end

  def create
    save_share!

    redirect_to edit_bean_public_bean_share_path(@bean), notice: t(".created")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_state(@share.selected_photo_attachment_ids)
  end

  def update
    save_share!

    redirect_to edit_bean_public_bean_share_path(@bean), notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    redirect_target = if params[:return_to] == "public_bean_shares"
      edit_workspace_path(anchor: "public-bean-shares")
    elsif params[:return_to] == "workspace"
      edit_workspace_path(anchor: "public-shares")
    else
      @bean
    end
    PublicBeanShare.transaction do
      @share.destroy!
      Activity::Emitter.record!(
        action: "public_bean_share.deleted", workspace: current_workspace,
        actor: Current.user, subject: @share
      )
    end

    redirect_to redirect_target, notice: t(".destroyed")
  end

  private
    def set_bean
      @bean = current_workspace
        .beans
        .includes(:public_bean_share, :record_links, :primary_photo_record, photos_attachments: :blob)
        .find(params[:bean_id])
    end

    def ensure_publishable_bean!
      return if PublicBeanShare.publishable_bean?(@bean)

      redirect_to @bean, alert: t("public_bean_shares.unsupported_status")
    end

    def set_or_build_share
      @share = @bean.public_bean_share || @bean.build_public_bean_share(
        workspace: current_workspace,
        created_by: Current.user,
        updated_by: Current.user,
        title: PublicBeanShare.default_title_for(@bean)
      )
    end

    def authorize_share_management!
      return if @share.manageable_by?(Current.user)

      redirect_to root_path, alert: t("authorization.denied")
    end

    def save_share!
      was_new = @share.new_record?
      was_enabled = @share.enabled?
      PublicBeanShare.transaction do
        @share.assign_attributes(
          title: share_params[:title],
          enabled: share_params[:enabled] == "1"
        )
        @share.created_by ||= Current.user
        @share.updated_by = Current.user
        apply_password_changes
        @share.refresh_snapshot!(
          title: share_params[:title],
          selected_photo_attachment_ids: permitted_selected_photo_attachment_ids,
          updated_by: Current.user
        )
        Activity::Emitter.record!(
          action: share_activity_action(prefix: "public_bean_share", was_new:, was_enabled:),
          workspace: current_workspace, actor: Current.user, subject: @share
        )
      end
    end

    def share_activity_action(prefix:, was_new:, was_enabled:)
      if was_new
        @share.enabled? ? "#{prefix}.published" : "#{prefix}.created"
      elsif !was_enabled && @share.enabled?
        "#{prefix}.published"
      elsif was_enabled && !@share.enabled?
        "#{prefix}.disabled"
      else
        "#{prefix}.updated"
      end
    end

    def apply_password_changes
      if share_params[:clear_password] == "1"
        @share.password_digest = nil
      elsif share_params[:password].present?
        @share.password = share_params[:password]
      end
    end

    def load_form_state(selected_photo_attachment_ids)
      @available_photos = available_photos
      @selected_photo_attachment_ids = Array(selected_photo_attachment_ids).map(&:to_i)
    end

    def available_photos
      @available_photos ||= @bean.photos.attachments.to_a
    end

    def default_selected_photo_attachment_ids
      Array(@bean.primary_photo_attachment).map(&:id)
    end

    def selected_photo_attachment_ids_from_params
      Array(share_params[:selected_photo_attachment_ids]).map(&:to_i)
    end

    def permitted_selected_photo_attachment_ids
      selected_photo_attachment_ids_from_params & available_photos.map(&:id)
    end

    def share_params
      params.fetch(:public_bean_share, {}).permit(
        :title,
        :enabled,
        :password,
        :clear_password,
        selected_photo_attachment_ids: []
      )
    end
end
