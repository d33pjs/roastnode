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
        metadata: metadata(event),
        created_at: event.created_at&.iso8601,
        updated_at: event.updated_at&.iso8601
      }
    end

    def metadata(event)
      # Metadata is already validated against the action contract. In particular,
      # this preserves the narrowly allowlisted guest IP for authorized exports.
      event.metadata.deep_dup
    end
    private_class_method :metadata
  end
end
