module Activity
  module Emitter
    module_function

    def record!(action:, workspace:, actor: nil, subject: nil, occurred_at: Time.current, visibility: nil, details: {})
      definition = EventContract.fetch(action)
      visibility ||= definition.fetch(:visibility)
      unless definition.fetch(:visibilities).include?(visibility)
        raise ArgumentError, "visibility is not permitted for #{action}"
      end
      validate_scope!(workspace:, visibility:, subject:, expected_subject_type: definition.fetch(:subject_type))

      ActivityEvent.create!(
        workspace:,
        actor:,
        category: definition.fetch(:category),
        action: action.to_s,
        occurred_at:,
        visibility:,
        subject:,
        metadata: Metadata.build(action:, actor:, subject:, details:)
      )
    end

    def validate_scope!(workspace:, visibility:, subject:, expected_subject_type:)
      if visibility == "instance_admin"
        raise ArgumentError, "instance activity cannot have a workspace" if workspace
      else
        raise ArgumentError, "workspace activity requires a workspace" unless workspace
      end
      if subject && subject.class.base_class.name != expected_subject_type
        raise ArgumentError, "activity subject type does not match action"
      end
      return unless workspace && subject
      subject_workspace_id = subject.is_a?(Workspace) ? subject.id : subject.workspace_id if subject.respond_to?(:workspace_id) || subject.is_a?(Workspace)
      return if subject_workspace_id.nil? || subject_workspace_id == workspace.id

      raise ArgumentError, "activity subject belongs to another workspace"
    end
  end
end
