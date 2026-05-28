class BeansController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update finish close reopen duplicate destroy]
  before_action :set_bean, only: %i[show edit update finish close reopen duplicate destroy]

  def index
    @beans = current_workspace.beans
      .includes(:primary_photo_record, photos_attachments: :blob)
      .order(Arel.sql("archived_at ASC NULLS FIRST"), Arel.sql("opened_on ASC NULLS LAST"), :name)
  end

  def show
    @bean_statistics_start_date, @bean_statistics_end_date = bean_statistics_date_range
    @bean_statistics = BeanStatistics.new(
      bean: @bean,
      start_date: @bean_statistics_start_date,
      end_date: @bean_statistics_end_date
    ).call
    @grinder_tendency_first_brew = @bean.brews.includes(:grinder).order(:occurred_at, :created_at).first
    @grinder_setting_suggestions = load_grinder_setting_suggestions
  end

  def new
    @bean = current_workspace.beans.new(opened_on: Date.current)
  end

  def edit
  end

  def create
    attributes = bean_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    bag_status = extract_bag_status(attributes)
    @bean = current_workspace.beans.new(attributes)
    @bean.apply_bag_status(bag_status)

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
    bag_status = extract_bag_status(attributes)
    @bean.assign_attributes(attributes)
    @bean.apply_bag_status(bag_status)

    if @bean.save
      @bean.photos.attach(photos) if photos.any?
      redirect_to @bean, notice: t(".updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def close
    @bean.archive!
    redirect_to @bean, notice: t(".closed")
  end

  def finish
    @bean.finish!
    redirect_to @bean, notice: t(".finished")
  end

  def reopen
    @bean.reopen!
    redirect_to @bean, notice: t(".reopened")
  end

  def duplicate
    duplicate = @bean.duplicate_for_new_bag!
    redirect_to edit_bean_path(duplicate), notice: t(".duplicated")
  end

  def destroy
    @bean.destroy_with_history!
    redirect_to beans_path, notice: t(".destroyed")
  end

  private
    DECIMAL_BEAN_FIELDS = %i[
      bag_size_grams
      remaining_grams
      roast_degree
      purchase_price
    ].freeze

    def set_bean
      @bean = current_workspace.beans.find(params[:id])
    end

    def bean_statistics_date_range
      start_date = parse_bean_statistics_date(params[:start_date])
      end_date = parse_bean_statistics_date(params[:end_date])

      if start_date.present? && end_date.present? && start_date > end_date
        [ end_date, start_date ]
      else
        [ start_date, end_date ]
      end
    end

    def parse_bean_statistics_date(value)
      return nil if value.blank?

      Date.iso8601(value)
    rescue ArgumentError
      nil
    end

    def load_grinder_setting_suggestions
      return [] unless grinder_setting_suggestions_requested?

      GrinderSettingSuggestion.new(bean: @bean).call
    end

    def grinder_setting_suggestions_requested?
      params[:suggest_grinder].present? || @bean.duplicated_from_bean_id.blank?
    end

    def extract_bag_status(attributes)
      attributes.delete(:bag_status).presence_in(Bean::BAG_STATUSES)
    end

    def bean_params
      normalize_decimal_attributes(params.expect(bean: [
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
        :bag_status,
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
      ]), *DECIMAL_BEAN_FIELDS)
    end
end
