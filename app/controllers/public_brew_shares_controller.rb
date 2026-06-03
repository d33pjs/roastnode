class PublicBrewSharesController < ApplicationController
  before_action :set_brew
  before_action :set_or_build_share
  before_action :authorize_share_management!

  def new
    load_form_state(default_selected_photo_attachment_ids)
  end

  def create
    save_share!

    redirect_to edit_brew_public_brew_share_path(@brew), notice: t(".created")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_state(@share.selected_photo_attachment_ids)
  end

  def update
    save_share!

    redirect_to edit_brew_public_brew_share_path(@brew), notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    redirect_target = params[:return_to] == "workspace" ? edit_workspace_path(anchor: "public-shares") : @brew
    @share.destroy!

    redirect_to redirect_target, notice: t(".destroyed")
  end

  private
    def set_brew
      @brew = current_workspace
        .brews
        .includes(:bean, :grinder, :machine, :user, brew_preparation_tools: :preparation_tool)
        .find(params[:brew_id])
    end

    def set_or_build_share
      @share = @brew.public_brew_share || @brew.build_public_brew_share(
        workspace: current_workspace,
        created_by: Current.user,
        updated_by: Current.user,
        title: default_title
      )
    end

    def authorize_share_management!
      return if @share.manageable_by?(Current.user)

      redirect_to root_path, alert: t("authorization.denied")
    end

    def save_share!
      PublicBrewShare.transaction do
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
      share_photo_records.flat_map { |record| record.photos.attachments }.compact.uniq(&:id)
    end

    def share_photo_records
      [
        @brew,
        @brew.bean,
        @brew.grinder,
        @brew.machine,
        *@brew.brew_preparation_tools.includes(:preparation_tool).filter_map(&:preparation_tool)
      ].compact.uniq
    end

    def default_selected_photo_attachment_ids
      share_photo_records.filter_map(&:primary_photo_attachment).map(&:id).uniq
    end

    def selected_photo_attachment_ids_from_params
      Array(share_params[:selected_photo_attachment_ids]).map(&:to_i)
    end

    def permitted_selected_photo_attachment_ids
      selected_photo_attachment_ids_from_params & available_photos.map(&:id)
    end

    def share_params
      params.fetch(:public_brew_share, {}).permit(
        :title,
        :enabled,
        :password,
        :clear_password,
        selected_photo_attachment_ids: []
      )
    end

    def default_title
      PublicBrewShare.default_title_for(@brew)
    end
end
