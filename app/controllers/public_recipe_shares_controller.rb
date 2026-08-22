class PublicRecipeSharesController < ApplicationController
  before_action :set_recipe
  before_action :set_or_build_share
  before_action :authorize_share_management!

  def new
    load_form_state([])
  end

  def create
    save_share!

    redirect_to edit_recipe_public_recipe_share_path(@recipe), notice: t(".created")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :new, status: :unprocessable_entity
  end

  def edit
    load_form_state(@share.selected_photo_attachment_ids)
  end

  def update
    save_share!

    redirect_to edit_recipe_public_recipe_share_path(@recipe), notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    load_form_state(permitted_selected_photo_attachment_ids)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    PublicRecipeShare.transaction do
      @share.destroy!
      Activity::Emitter.record!(
        action: "public_recipe_share.deleted", workspace: current_workspace,
        actor: Current.user, subject: @share
      )
    end

    redirect_to @recipe, notice: t(".destroyed")
  end

  private
    def set_recipe
      @recipe = current_workspace
        .recipes
        .includes(:created_by, :record_links, :primary_photo_record, photos_attachments: :blob)
        .find(params[:recipe_id])
    end

    def set_or_build_share
      @share = @recipe.public_recipe_share || @recipe.build_public_recipe_share(
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
      was_new = @share.new_record?
      was_enabled = @share.enabled?
      PublicRecipeShare.transaction do
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
          action: Activity::ShareAction.resolve(
            prefix: "public_recipe_share", was_new:, was_enabled:, enabled: @share.enabled?
          ),
          workspace: current_workspace, actor: Current.user, subject: @share
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
      Array(@recipe.primary_photo_attachment)
    end

    def selected_photo_attachment_ids_from_params
      Array(share_params[:selected_photo_attachment_ids]).map(&:to_i)
    end

    def permitted_selected_photo_attachment_ids
      selected_photo_attachment_ids_from_params & available_photos.map(&:id)
    end

    def share_params
      params.fetch(:public_recipe_share, {}).permit(
        :title,
        :enabled,
        :password,
        :clear_password,
        selected_photo_attachment_ids: []
      )
    end

    def default_title
      @recipe.title
    end
end
