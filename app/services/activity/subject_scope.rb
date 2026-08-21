module Activity
  module SubjectScope
    module_function

    def compatible?(subject:, workspace:)
      return true unless subject
      return workspace.nil? || subject.id == workspace.id if subject.is_a?(Workspace)
      return workspace.nil? || subject.memberships.exists?(workspace:) if subject.is_a?(User)
      if subject.is_a?(PasskeyCredential)
        return workspace.nil? || subject.user.memberships.exists?(workspace:)
      end
      return true unless subject.respond_to?(:workspace_id)

      workspace ? subject.workspace_id == workspace.id : subject.workspace_id.nil?
    end
  end
end
