class BeansController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update close reopen duplicate]
  before_action :set_bean, only: %i[show edit update close reopen duplicate]

  def index
    @beans = current_workspace.beans.order(Arel.sql("archived_at ASC NULLS FIRST"), Arel.sql("opened_on ASC NULLS LAST"), :name)
  end

  def show
  end

  def new
    @bean = current_workspace.beans.new(opened_on: Date.current)
  end

  def edit
  end

  def create
    attributes = bean_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    @bean = current_workspace.beans.new(attributes)

    if @bean.save
      @bean.photos.attach(photos) if photos.any?
      redirect_to @bean, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    attributes = bean_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)

    if @bean.update(attributes)
      @bean.photos.attach(photos) if photos.any?
      redirect_to @bean, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def close
    @bean.close!
    redirect_to @bean, notice: t(".closed")
  end

  def reopen
    @bean.reopen!
    redirect_to @bean, notice: t(".reopened")
  end

  def duplicate
    duplicate = @bean.duplicate_for_new_bag!
    redirect_to edit_bean_path(duplicate), notice: t(".duplicated")
  end

  private
    def set_bean
      @bean = current_workspace.beans.find(params[:id])
    end

    def bean_params
      params.expect(bean: [
        :name,
        :roaster_name,
        :origin,
        :process,
        :roast_date,
        :roast_type,
        :roast_level,
        :roast_degree,
        :tasting_notes,
        :bag_size_grams,
        :remaining_grams,
        :opened_on,
        :blend_type,
        :decaffeinated,
        :purchase_source,
        :purchase_url,
        :purchased_on,
        :purchase_price,
        :rating,
        :notes,
        :country,
        :region,
        :farm,
        :farmer,
        :elevation,
        :variety,
        :harvested,
        :blend_percentage,
        { photos: [] }
      ])
    end
end
