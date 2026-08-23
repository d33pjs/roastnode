class BeansController < ApplicationController
  INDEX_GROUPS = [
    { key: "open", statuses: %w[open] },
    { key: "stock", statuses: %w[stock] },
    { key: "finished", statuses: %w[finished used_up] },
    { key: "archived", statuses: %w[archived] }
  ].freeze

  before_action :authorize_workspace_write!, only: %i[new create edit update rating finish close open_bag reopen duplicate destroy roaster_suggestions]
  before_action :set_bean, only: %i[show edit update rating finish close open_bag reopen duplicate destroy]

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
    prepare_show
  end

  def new
    @bean = current_workspace.beans.new
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
    bag_status = extract_bag_status(attributes) || "stock"
    @bean = current_workspace.beans.new(attributes)
    @bean.apply_bag_status(bag_status)

    created = with_workspace_activity(action: "bean.created", subject: -> { @bean }) do
      saved = @bean.save
      if saved
        @bean.photos.attach(photos) if photos.any?
        refresh_public_shares_for(@bean)
      end
      saved
    end

    if created
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
    previous_status = @bean.bag_status
    @bean.assign_attributes(attributes)
    @bean.apply_bag_status(bag_status)

    updated = with_workspace_activity(
      action: -> { bean_update_activity_action(previous_status) }, subject: @bean
    ) do
      saved = @bean.save
      if saved
        @bean.photos.attach(photos) if photos.any?
        refresh_public_shares_for(@bean)
      end
      saved
    end

    if updated
      redirect_to @bean, notice: t(".updated")
    else
      prepare_record_links(@bean)
      render :edit, status: :unprocessable_entity
    end
  end

  def rating
    normalized_rating = rating_bean_params[:rating].presence

    with_workspace_activity(action: "bean.updated", subject: @bean) do
      @bean.update!(rating: normalized_rating)
      refresh_public_shares_for(@bean)
      true
    end

    redirect_to @bean, notice: t(".updated")
  rescue ActiveRecord::RecordInvalid => error
    @bean.reload unless error.record.equal?(@bean)
    prepare_show
    render :show, status: :unprocessable_entity
  end

  def close
    with_workspace_activity(action: "bean.archived", subject: @bean) do
      @bean.archive!
      refresh_public_shares_for(@bean)
      true
    end
    redirect_to @bean, notice: t(".closed")
  end

  def open_bag
    if @bean.stock?
      with_workspace_activity(action: "bean.opened", subject: @bean) do
        @bean.open_bag!
        refresh_public_shares_for(@bean)
        true
      end
      redirect_back_or_to @bean, allow_other_host: false, notice: t(".opened")
    else
      redirect_to @bean, alert: t(".not_stock")
    end
  end

  def finish
    with_workspace_activity(action: "bean.finished", subject: @bean) do
      @bean.finish!
      refresh_public_shares_for(@bean)
      true
    end
    redirect_to @bean, notice: t(".finished")
  end

  def reopen
    with_workspace_activity(action: "bean.reopened", subject: @bean) do
      @bean.reopen!
      refresh_public_shares_for(@bean)
      true
    end
    redirect_to @bean, notice: t(".reopened")
  end

  def duplicate
    duplicate = nil
    with_workspace_activity(
      action: "bean.duplicated",
      subject: -> { duplicate },
      details: -> { { source_label: @bean.display_name } }
    ) do
      duplicate = @bean.duplicate_for_new_bag!
      true
    end
    redirect_to edit_bean_path(duplicate), notice: t(".duplicated")
  end

  def destroy
    _subject_label = Activity::Metadata.subject_label(@bean)
    with_workspace_activity(action: "bean.deleted", subject: @bean) do
      @bean.destroy_with_history!
      PublicBeanShareRefresher.refresh_comparisons_for(@bean)
      true
    end
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

    def rating_bean_params
      params.expect(bean: [ :rating ])
    end

    def prepare_show
      @bean_statistics = BeanStatistics.new(bean: @bean).call
      @grinder_tendency_first_brew = @bean.brews.espresso
        .includes(:grinder)
        .order(:occurred_at, :created_at)
        .first
      @grinder_setting_suggestions = load_grinder_setting_suggestions
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
        :coffee_origin_url,
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

    def bean_update_activity_action(previous_status)
      current_status = @bean.bag_status
      return "bean.updated" if current_status == previous_status

      return "bean.opened" if previous_status == "stock" && current_status == "open"
      return "bean.reopened" if current_status == "open" && previous_status.in?(%w[finished used_up archived])
      return "bean.finished" if current_status == "finished"
      return "bean.used_up" if current_status == "used_up"
      return "bean.archived" if current_status == "archived"

      "bean.updated"
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
