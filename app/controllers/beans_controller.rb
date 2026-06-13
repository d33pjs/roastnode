class BeansController < ApplicationController
  INDEX_GROUPS = [
    { key: "open", statuses: %w[open] },
    { key: "stock", statuses: %w[stock] },
    { key: "finished", statuses: %w[finished used_up] },
    { key: "archived", statuses: %w[archived] }
  ].freeze

  before_action :authorize_workspace_write!, only: %i[new create edit update finish close open_bag reopen duplicate destroy roaster_suggestions]
  before_action :set_bean, only: %i[show edit update finish close open_bag reopen duplicate destroy]

  def index
    @beans = current_workspace.beans
      .left_joins(:brews)
      .includes(:primary_photo_record, photos_attachments: :blob)
      .select("beans.*, MAX(brews.occurred_at) AS latest_brew_at")
      .group("beans.id")
      .to_a
    @bean_groups = bean_index_groups(@beans)
  end

  def show
    @bean_statistics = BeanStatistics.new(bean: @bean).call
    @grinder_tendency_first_brew = @bean.brews.espresso.includes(:grinder).order(:occurred_at, :created_at).first
    @grinder_setting_suggestions = load_grinder_setting_suggestions
  end

  def new
    @bean = current_workspace.beans.new(opened_on: Date.current)
    prepare_record_links(@bean)
  end

  def roaster_suggestions
    query = params[:q].to_s.strip
    suggestions = roaster_name_suggestions_for(query)

    render json: { suggestions: suggestions }
  end

  def edit
    prepare_record_links(@bean)
  end

  def create
    attributes = bean_params
    photos = Array(attributes.delete(:photos)).reject(&:blank?)
    bag_status = extract_bag_status(attributes)
    @bean = current_workspace.beans.new(attributes)
    @bean.apply_bag_status(bag_status)

    if @bean.save
      @bean.photos.attach(photos) if photos.any?
      refresh_public_shares_for(@bean)
      redirect_to @bean, notice: t(".created")
    else
      prepare_record_links(@bean)
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
      refresh_public_shares_for(@bean)
      redirect_to @bean, notice: t(".updated")
    else
      prepare_record_links(@bean)
      render :edit, status: :unprocessable_entity
    end
  end

  def close
    @bean.archive!
    refresh_public_shares_for(@bean)
    redirect_to @bean, notice: t(".closed")
  end

  def open_bag
    if @bean.stock?
      @bean.open_bag!
      refresh_public_shares_for(@bean)
      redirect_back fallback_location: @bean, notice: t(".opened")
    else
      redirect_to @bean, alert: t(".not_stock")
    end
  end

  def finish
    @bean.finish!
    refresh_public_shares_for(@bean)
    redirect_to @bean, notice: t(".finished")
  end

  def reopen
    @bean.reopen!
    refresh_public_shares_for(@bean)
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
        :grind_state,
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
        :continent,
        :country,
        :country_of_manufacturer,
        :region,
        :farm,
        :farmer,
        :elevation,
        :manufacturer,
        :variety,
        :harvested,
        :blend_percentage,
        :public_note,
        {
          photos: [],
          record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
        }
      ]), *DECIMAL_BEAN_FIELDS)
    end

    def prepare_record_links(record)
      record.prepare_record_links_for_form
    end

    def roaster_name_suggestions_for(query)
      return [] if query.blank?

      current_workspace.beans
        .where.not(roaster_name: [ nil, "" ])
        .where("roaster_name ILIKE ?", "%#{Bean.sanitize_sql_like(query)}%")
        .pluck(:roaster_name)
        .map { |name| name.to_s.strip }
        .reject(&:blank?)
        .uniq { |name| name.downcase }
        .sort_by(&:downcase)
        .first(8)
    end

    def refresh_public_shares_for(record)
      PublicBrewShareRefresher.refresh_for(record)
      PublicBeanShareRefresher.refresh_for(record)
    end

    def bean_index_groups(beans)
      INDEX_GROUPS.filter_map do |group|
        grouped_beans = beans.select { |bean| group.fetch(:statuses).include?(bean.bag_status) }
        next if grouped_beans.empty?

        {
          key: group.fetch(:key),
          beans: sort_beans_for_index(group.fetch(:key), grouped_beans)
        }
      end
    end

    def sort_beans_for_index(group_key, beans)
      beans.sort_by do |bean|
        case group_key
        when "open"
          [
            descending_time_sort(bean[:latest_brew_at]),
            descending_time_sort(bean.opened_on),
            descending_time_sort(bean.created_at),
            bean.name.to_s.downcase
          ]
        when "stock"
          [
            descending_time_sort(bean.purchased_on),
            descending_time_sort(bean.roast_date),
            descending_time_sort(bean.created_at),
            bean.name.to_s.downcase
          ]
        when "finished"
          [
            descending_time_sort(bean.finished_at || bean[:latest_brew_at]),
            descending_time_sort(bean[:latest_brew_at]),
            descending_time_sort(bean.opened_on),
            bean.name.to_s.downcase
          ]
        else
          [
            descending_time_sort(bean.archived_at),
            descending_time_sort(bean.opened_on),
            bean.name.to_s.downcase
          ]
        end
      end
    end

    def descending_time_sort(value)
      return Float::INFINITY if value.blank?

      -value.to_time.to_i
    end
end
