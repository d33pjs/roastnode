class BeanLeftoverTransfer
  class InvalidTransfer < StandardError; end

  def self.matching?(source, destination)
    return false if source.id == destination.id || source.workspace_id != destination.workspace_id
    return false unless source.grind_state == destination.grind_state

    source.coffee_history_id == destination.coffee_history_id ||
      (source.roaster_name.present? && source.name.to_s.squish.downcase == destination.name.to_s.squish.downcase &&
        source.roaster_name.to_s.squish.downcase == destination.roaster_name.to_s.squish.downcase)
  end

  def self.destinations(source)
    source.workspace.beans.where(archived_at: nil, finished_at: nil).where("remaining_grams > 0")
      .order(created_at: :desc, id: :desc).select { |bean| matching?(source, bean) }
  end

  def initialize(source:, destination:, user:)
    @source = source
    @destination_choice = destination.to_s
    @user = user
  end

  def call
    Bean.transaction do
      destination = @source.workspace.beans.find(@destination_choice) unless @destination_choice == "new"
      locked = @source.workspace.beans.where(id: [ @source.id, destination&.id ].compact).order(:id).lock.index_by(&:id)
      @source = locked.fetch(@source.id)
      raise InvalidTransfer unless @source.opened_on.present? && !@source.archived? && @source.remaining_grams.positive?

      if @destination_choice == "new"
        destination = @source.duplicate_for_new_bag!
        record("bean.duplicated", destination, details: { source_label: @source.display_name })
      else
        destination = locked.fetch(destination.id)
      end
      raise InvalidTransfer unless self.class.matching?(@source, destination) && (destination.stock? || destination.open?)

      if destination.stock?
        destination.open_bag!
        record("bean.opened", destination)
      end
      amount = @source.remaining_grams
      @source.update!(remaining_grams: 0)
      destination.update!(remaining_grams: destination.remaining_grams + amount)
      [ [ @source, -amount ], [ destination, amount ] ].each do |bean, delta|
        adjustment = bean.inventory_adjustments.create!(workspace: @source.workspace, user: @user,
          reason: "transfer", delta_grams: delta, note: "Leftover transfer.")
        record("inventory_adjustment.created", adjustment)
      end
      @source.finish! unless @source.finished?
      record("bean.finished", @source)
      yield @source, destination if block_given?
      destination
    end
  end

  private
    def record(action, subject, details: {})
      Activity::Emitter.record!(action:, subject:, workspace: @source.workspace, actor: @user, details:)
    end
end
