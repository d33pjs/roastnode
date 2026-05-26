class WorkspacePolicy
  def initialize(membership)
    @membership = membership
  end

  def read?
    membership.present?
  end

  def write?
    membership&.can_write_workspace_data? || false
  end

  def manage?
    membership&.can_manage_workspace? || false
  end

  private
    attr_reader :membership
end
