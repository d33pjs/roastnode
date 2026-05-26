class BeansController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create]
  before_action :set_bean, only: :show

  def index
    @beans = current_workspace.beans.order(Arel.sql("archived_at ASC NULLS FIRST"), Arel.sql("opened_on ASC NULLS LAST"), :name)
  end

  def show
  end

  def new
    @bean = current_workspace.beans.new(opened_on: Date.current)
  end

  def create
    @bean = current_workspace.beans.new(bean_params)

    if @bean.save
      redirect_to @bean, notice: t(".created")
    else
      render :new, status: :unprocessable_entity
    end
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
        :roast_level,
        :tasting_notes,
        :bag_size_grams,
        :remaining_grams,
        :opened_on,
        :purchase_source,
        :purchase_url,
        :purchased_on,
        :purchase_price_cents,
        :rating,
        :notes
      ])
    end
end
