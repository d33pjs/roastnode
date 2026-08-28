module Activity
  module Emitter
    module_function

    def record!(action:, workspace:, actor: nil, actor_kind: nil, actor_label: nil, subject: nil, occurred_at: Time.current, visibility: nil, details: {})
      definition = EventContract.fetch(action)
      visibility ||= definition.fetch(:visibility)
      unless definition.fetch(:visibilities).include?(visibility)
        raise ArgumentError, "visibility is not permitted for #{action}"
      end
      validate_scope!(
        workspace:,
        visibility:,
        subject:,
        expected_subject_type: definition.fetch(:subject_type),
        subject_required: definition.fetch(:subject_required)
      )

      ActivityEvent.create!(
        workspace:,
        actor:,
        category: definition.fetch(:category),
        action: action.to_s,
        occurred_at:,
        visibility:,
        subject:,
        metadata: Metadata.build(action:, actor:, actor_kind:, actor_label:, subject:, details:)
      )
    end

    def validate_scope!(workspace:, visibility:, subject:, expected_subject_type:, subject_required:)
      if visibility == "instance_admin"
        raise ArgumentError, "instance activity cannot have a workspace" if workspace
      else
        raise ArgumentError, "workspace activity requires a workspace" unless workspace
      end
      raise ArgumentError, "activity action requires a subject" if subject_required && subject.nil?

      if subject && subject.class.base_class.name != expected_subject_type
        raise ArgumentError, "activity subject type does not match action"
      end
      return if SubjectScope.compatible?(subject:, workspace:)

      raise ArgumentError, "activity subject belongs to another workspace"
    end
  end
end
