class PublicRecipeSharesController < ApplicationController
  before_action :set_recipe
  before_action :set_or_build_share
  before_action :authorize_share_management!

  def new
  end

  def create
    save_share!

    redirect_to edit_recipe_public_recipe_share_path(@recipe), notice: t(".created")
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    save_share!

    redirect_to edit_recipe_public_recipe_share_path(@recipe), notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    render :edit, status: :unprocessable_entity
  end

  def destroy
    @share.destroy!

    redirect_to @recipe, notice: t(".destroyed")
  end

  private
    def set_recipe
      @recipe = current_workspace
        .recipes
        .includes(:created_by, :record_links)
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

    def share_params
      params.fetch(:public_recipe_share, {}).permit(
        :title,
        :enabled,
        :password,
        :clear_password
      )
    end

    def default_title
      @recipe.title
    end
end
