module Activity
  module ExportSerializer
    module_function

    def call(event)
      {
        id: event.id,
        workspace_id: event.workspace_id,
        actor_id: event.actor_id,
        category: event.category,
        action: event.action,
        occurred_at: event.occurred_at&.iso8601,
        visibility: event.visibility,
        subject_type: event.subject_type,
        subject_id: event.subject_id,
        metadata: event.metadata.deep_dup,
        created_at: event.created_at&.iso8601,
        updated_at: event.updated_at&.iso8601
      }
    end
  end
end
