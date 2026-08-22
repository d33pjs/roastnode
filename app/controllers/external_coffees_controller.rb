class ExternalCoffeesController < ApplicationController
  before_action :authorize_workspace_write!, only: %i[new create edit update destroy drink_type_suggestions place_name_suggestions]
  before_action :set_external_coffee, only: %i[show edit update destroy]

  def index
    @external_coffees = HistoryPaginator.new(
      current_workspace.external_coffees.includes(:user, :primary_photo_record, photos_attachments: :blob).recent,
      page: params[:page]
    )
  end

  def show
  end

  def new
    @external_coffee = current_workspace.external_coffees.new(
      user: Current.user,
      occurred_at: Time.current,
      currency: current_workspace.default_currency
    )
    prepare_form_options
    prepare_record_links(@external_coffee)
  end

  def create
    @external_coffee = current_workspace.external_coffees.new(external_coffee_params)
    @external_coffee.user = Current.user

    created = with_workspace_activity(
      action: "external_coffee.created",
      subject: -> { @external_coffee },
      occurred_at: -> { @external_coffee.occurred_at }
    ) do
      @external_coffee.save
    end

    if created
      redirect_to @external_coffee, notice: t(".created")
    else
      prepare_form_options
      prepare_record_links(@external_coffee)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_form_options
    prepare_record_links(@external_coffee)
  end

  def update
    updated = with_workspace_activity(action: "external_coffee.updated", subject: @external_coffee) do
      @external_coffee.update(external_coffee_params)
    end

    if updated
      redirect_to @external_coffee, notice: t(".updated")
    else
      prepare_form_options
      prepare_record_links(@external_coffee)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    _subject_label = Activity::Metadata.subject_label(@external_coffee)
    with_workspace_activity(action: "external_coffee.deleted", subject: @external_coffee) do
      @external_coffee.destroy!
    end
    redirect_to external_coffees_path, notice: t(".destroyed")
  end

  def drink_type_suggestions
    render json: { suggestions: suggestions_for(:drink_type, seeded: ExternalCoffee::DRINK_TYPE_SUGGESTIONS) }
  end

  def place_name_suggestions
    render json: { suggestions: suggestions_for(:place_name) }
  end

  private
    DECIMAL_FIELDS = %i[latitude longitude].freeze

    def set_external_coffee
      @external_coffee = current_workspace
        .external_coffees
        .includes(:user, :record_links, :primary_photo_record, photos_attachments: :blob)
        .find(params[:id])
    end

    def external_coffee_params
      attributes = params.expect(external_coffee: [
        :occurred_at,
        :drink_type,
        :drink_size,
        :place_name,
        :place_location,
        :latitude,
        :longitude,
        :price,
        :currency,
        :acidity_balance,
        :intensity,
        :rating,
        :notes,
        :public_note,
        photos: [],
        record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
      ])

      attributes = normalize_decimal_attributes(attributes, *DECIMAL_FIELDS)
      discard_blank_photo_params(attributes)
    end

    def discard_blank_photo_params(attributes)
      return attributes unless attributes.key?(:photos)

      photos = Array(attributes[:photos]).compact_blank
      if photos.empty?
        attributes.delete(:photos)
      else
        attributes[:photos] = photos
      end

      attributes
    end

    def prepare_form_options
      @drink_type_suggestions = combined_drink_type_suggestions
      @place_name_suggestions = history_suggestions_for(:place_name)
    end

    def prepare_record_links(record)
      record.prepare_record_links_for_form
    end

    def suggestions_for(field, seeded: [])
      query = params[:q].to_s.strip.downcase
      return [] if query.blank?

      (seeded + history_suggestions_for(field))
        .compact_blank
        .uniq
        .select { |value| value.downcase.include?(query) }
        .first(10)
    end

    def combined_drink_type_suggestions
      (ExternalCoffee::DRINK_TYPE_SUGGESTIONS + history_suggestions_for(:drink_type)).uniq
    end

    def history_suggestions_for(field)
      current_workspace
        .external_coffees
        .where.not(field => [ nil, "" ])
        .distinct
        .order(field)
        .limit(50)
        .pluck(field)
    end
end
