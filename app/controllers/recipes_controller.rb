class RecipesController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  before_action :authorize_workspace_write!, only: %i[new create edit update destroy log export import]
  before_action :set_recipe, only: %i[show edit update destroy log export]

  def index
    @recipes = current_workspace
      .recipes
      .includes(:source_brew)
      .order(created_at: :desc, id: :desc)
  end

  def show
  end

  def new
    source_brew = source_brew_from_params!
    @source_brew_primary_photo = source_brew.primary_photo_attachment
    profile = RecipeSnapshotBuilder.new(brew: source_brew, title: default_title(source_brew)).call
    @recipe = current_workspace.recipes.new(
      created_by: Current.user,
      source_brew: source_brew,
      title: profile["title"],
      method: profile["method"],
      profile: profile,
      source_snapshot: source_snapshot_from_profile(profile)
    )
    prepare_record_links(@recipe)
  end

  def create
    source_brew = source_brew_from_params!
    profile = RecipeSnapshotBuilder.new(brew: source_brew, title: default_title(source_brew)).call
    profile = profile_from_params(profile)
    @recipe = current_workspace.recipes.new(
      created_by: Current.user,
      source_brew: source_brew,
      title: profile["title"],
      method: profile["method"],
      profile: profile,
      source_snapshot: source_snapshot_from_profile(profile)
    )
    assign_record_link_attributes(@recipe)
    assign_recipe_photos(@recipe, source_brew)

    if @recipe.save
      redirect_to @recipe, notice: t(".created")
    else
      prepare_record_links(@recipe)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    prepare_record_links(@recipe)
  end

  def update
    uploaded_photos = uploaded_recipe_photos
    profile = profile_from_params(@recipe.profile.deep_dup)
    @recipe.assign_attributes(title: profile["title"], profile: profile)
    assign_record_link_attributes(@recipe)

    if @recipe.save
      assign_uploaded_recipe_photos_as_primary(@recipe, uploaded_photos)
      redirect_to @recipe, notice: t(".updated")
    else
      prepare_record_links(@recipe)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @recipe.destroy
    redirect_to recipes_path, notice: t(".destroyed")
  end

  def log
    redirect_to new_brew_path(recipe_id: @recipe.id)
  end

  def export
    send_data JSON.pretty_generate(RecipeExporter.new(@recipe).call),
      filename: @recipe.export_filename,
      type: "application/json",
      disposition: "attachment"
  end

  def import
    uploaded_file = params.dig(:recipe_import, :file)

    if uploaded_file.blank?
      redirect_to recipes_path, alert: t(".missing_file")
      return
    end

    recipe = RecipeImporter.new(
      workspace: current_workspace,
      user: Current.user,
      json: uploaded_file.read
    ).call

    redirect_to recipe, notice: t(".created")
  rescue RecipeImporter::ImportError => error
    redirect_to recipes_path, alert: error.message
  end

  private
    TARGET_DECIMAL_FIELDS = %i[
      bean_weight_grams
      ground_weight_grams
      dose_grams
      beverage_grams
      brew_temperature_celsius
    ].freeze
    TARGET_INTEGER_FIELDS = %i[
      preinfusion_seconds
      first_drip_seconds
      total_time_seconds
    ].freeze
    TARGET_TEXT_FIELDS = %i[grind_setting].freeze
    TARGET_FIELDS = (TARGET_DECIMAL_FIELDS + TARGET_INTEGER_FIELDS + TARGET_TEXT_FIELDS).freeze
    INGREDIENT_FIELDS = %i[amount unit name].freeze
    INGREDIENT_MAX_LENGTHS = {
      "amount" => 32,
      "unit" => 32,
      "name" => 120
    }.freeze
    FINISH_NOTE_MAX_LENGTH = 1_000

    def set_recipe
      @recipe = current_workspace
        .recipes
        .includes(:source_brew, :record_links)
        .find(params[:id])
    end

    def source_brew_from_params!
      source_brew_id = recipe_params[:source_brew_id].presence || params[:source_brew_id].presence
      current_workspace
        .brews
        .includes(:bean, :grinder, :machine, :record_links, :primary_photo_record, photos_attachments: :blob, brew_preparation_tools: :preparation_tool)
        .find(source_brew_id)
    end

    def default_title(source_brew)
      "Espresso with #{source_brew.bean.display_name}"
    end

    def profile_from_params(profile)
      attributes = recipe_params
      title = attributes[:title].presence || profile["title"]
      profile["title"] = title
      profile["guide"] = guide_from_params(profile["guide"] || {})
      profile["targets"] = targets_from_params(profile["targets"] || {})
      profile["ingredients"] = ingredients_from_params if attributes.key?(:ingredients)
      profile["finish_note"] = finish_note_from_params if attributes.key?(:finish_note)
      profile.compact
    end

    def guide_from_params(existing_guide)
      existing_guide.merge(
        "note" => recipe_params[:guide_note].presence,
        "pressure_note" => recipe_params[:pressure_note].presence
      ).compact
    end

    def targets_from_params(existing_targets)
      incoming_targets = recipe_params[:targets] || ActionController::Parameters.new
      return existing_targets if incoming_targets.blank?

      normalized_targets = normalize_decimal_attributes(incoming_targets, *TARGET_DECIMAL_FIELDS)
      TARGET_DECIMAL_FIELDS.each do |field|
        value = normalized_targets[field]
        existing_targets[field.to_s] = value if value.present?
      end
      TARGET_INTEGER_FIELDS.each do |field|
        value = incoming_targets[field]
        existing_targets[field.to_s] = value.to_i if value.present?
      end
      TARGET_TEXT_FIELDS.each do |field|
        value = incoming_targets[field]
        existing_targets[field.to_s] = value if value.present?
      end
      existing_targets
    end

    def ingredients_from_params
      ingredient_rows_from_params(recipe_params[:ingredients]).filter_map do |row|
        payload = INGREDIENT_FIELDS.each_with_object({}) do |field, result|
          key = field.to_s
          value = ingredient_row_value(row, field).to_s.strip.first(INGREDIENT_MAX_LENGTHS.fetch(key))
          result[key] = value if value.present?
        end
        payload if payload["name"].present?
      end
    end

    def ingredient_rows_from_params(rows)
      case rows
      when ActionController::Parameters
        rows.to_unsafe_h.values
      when Hash
        rows.values
      when Array
        rows
      else
        []
      end
    end

    def ingredient_row_value(row, field)
      row = row.to_unsafe_h if row.respond_to?(:to_unsafe_h)
      return unless row.respond_to?(:key?)

      row[field.to_s] || row[field]
    end

    def finish_note_from_params
      recipe_params[:finish_note].to_s.strip.first(FINISH_NOTE_MAX_LENGTH).presence
    end

    def source_snapshot_from_profile(profile)
      { "source_brew" => profile["source_brew"] }.compact
    end

    def assign_record_link_attributes(recipe)
      return unless recipe_params.key?(:record_links_attributes)

      recipe.assign_attributes(record_links_attributes: recipe_params[:record_links_attributes])
    end

    def prepare_record_links(record)
      record.prepare_record_links_for_form
    end

    def assign_recipe_photos(recipe, source_brew)
      assign_uploaded_recipe_photos(recipe)
      attach_source_brew_photo(recipe, source_brew) if recipe_params[:use_source_brew_photo] == "1"
    end

    def assign_uploaded_recipe_photos(recipe)
      photos = uploaded_recipe_photos
      recipe.photos.attach(photos) if photos.any?
    end

    def assign_uploaded_recipe_photos_as_primary(recipe, photos)
      photos = Array(photos).reject(&:blank?)
      return if photos.blank?

      recipe.photos.attach(photos)
      new_attachment = recipe.photos.attachments.order(:id).last
      recipe.set_primary_photo!(new_attachment) if new_attachment
    end

    def uploaded_recipe_photos
      Array(recipe_params[:photos]).reject(&:blank?)
    end

    def attach_source_brew_photo(recipe, source_brew)
      attachment = source_brew.primary_photo_attachment
      requested_id = recipe_params[:source_brew_photo_attachment_id].presence&.to_i
      raise ActiveRecord::RecordNotFound if requested_id && (attachment.blank? || requested_id != attachment.id)
      return if attachment.blank?

      recipe.photos.attach(attachment.blob)
    end

    def recipe_params
      @recipe_params ||= recipe_parameter_source.permit(
        :source_brew_id,
        :title,
        :guide_note,
        :pressure_note,
        :finish_note,
        :use_source_brew_photo,
        :source_brew_photo_attachment_id,
        :photos,
        targets: TARGET_FIELDS,
        ingredients: [ INGREDIENT_FIELDS ],
        photos: [],
        record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
      )
    end

    def recipe_parameter_source
      params[:recipe].presence || ActionController::Parameters.new
    end

    def render_not_found
      head :not_found
    end
end
