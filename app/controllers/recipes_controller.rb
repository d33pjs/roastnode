class RecipesController < ApplicationController
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
    profile = profile_from_params(@recipe.profile.deep_dup)
    @recipe.assign_attributes(title: profile["title"], profile: profile)
    assign_record_link_attributes(@recipe)

    if @recipe.save
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
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end

    def source_brew_from_params!
      source_brew_id = recipe_params[:source_brew_id].presence || params[:source_brew_id].presence
      current_workspace
        .brews
        .includes(:bean, :grinder, :machine, :record_links, brew_preparation_tools: :preparation_tool)
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
      rows = recipe_params[:ingredients] || ActionController::Parameters.new
      rows.to_unsafe_h.values.filter_map do |row|
        payload = INGREDIENT_FIELDS.each_with_object({}) do |field, result|
          key = field.to_s
          value = row[key].to_s.strip.first(INGREDIENT_MAX_LENGTHS.fetch(key))
          result[key] = value if value.present?
        end
        payload if payload["name"].present?
      end
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

    def recipe_params
      @recipe_params ||= recipe_parameter_source.permit(
        :source_brew_id,
        :title,
        :guide_note,
        :pressure_note,
        :finish_note,
        targets: TARGET_FIELDS,
        ingredients: [ INGREDIENT_FIELDS ],
        record_links_attributes: [ [ :id, :label, :url, :kind, :visibility, :position, :_destroy ] ]
      )
    end

    def recipe_parameter_source
      params[:recipe].presence || ActionController::Parameters.new
    end
end
