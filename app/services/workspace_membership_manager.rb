class WorkspaceMembershipManager
  Result = Struct.new(:success, :error, keyword_init: true) do
    def success?
      success
    end
  end

  ADMIN_MANAGED_ROLES = %w[member viewer].freeze
  OWNER_ASSIGNABLE_ROLES = %w[admin member viewer].freeze

  def initialize(workspace:, actor_membership:)
    @workspace = workspace
    @actor_membership = actor_membership
  end

  def update_role(target_membership, role)
    role = role.to_s
    return failure(:invalid_role) unless Membership.roles.key?(role)
    return failure(:last_owner) if target_membership.owner? && role != "owner" && sole_owner?(target_membership)
    return failure(:unauthorized) unless can_update_role?(target_membership, role)

    old_role = target_membership.role
    Membership.transaction do
      target_membership.update!(role:)
      Activity::Emitter.record!(
        action: "membership.role_changed", workspace:, actor: actor_membership.user,
        subject: target_membership, details: { from_role: old_role, to_role: role }
      )
    end
    success
  end

  def remove(target_membership)
    return failure(:last_owner) if target_membership.owner? && sole_owner?(target_membership)
    return failure(:unauthorized) unless can_remove?(target_membership)

    Membership.transaction do
      target_user = target_membership.user
      target_membership.destroy!
      target_user.update!(active_workspace: nil) if target_user.active_workspace_id == workspace.id
      Activity::Emitter.record!(
        action: "membership.removed", workspace:, actor: actor_membership.user, subject: target_membership
      )
    end
    success
  end

  def transfer_ownership(target_membership)
    return failure(:unauthorized) unless actor_membership&.owner?
    return failure(:transfer_self) if target_membership.id == actor_membership.id

    old_actor_role = actor_membership.role
    Membership.transaction do
      target_membership.update!(role: "owner")
      actor_membership.update!(role: "admin")
      Activity::Emitter.record!(
        action: "membership.ownership_transferred", workspace:, actor: actor_membership.user,
        subject: target_membership, details: { from_role: old_actor_role, to_role: "owner" }
      )
    end

    success
  end

  private
    attr_reader :workspace, :actor_membership

    def can_update_role?(target_membership, role)
      return false unless same_workspace?(target_membership)

      if actor_membership&.owner?
        return false if target_membership.owner?

        OWNER_ASSIGNABLE_ROLES.include?(role)
      elsif actor_membership&.admin?
        ADMIN_MANAGED_ROLES.include?(target_membership.role) && ADMIN_MANAGED_ROLES.include?(role)
      else
        false
      end
    end

    def can_remove?(target_membership)
      return false unless same_workspace?(target_membership)

      if actor_membership&.owner?
        !target_membership.owner?
      elsif actor_membership&.admin?
        ADMIN_MANAGED_ROLES.include?(target_membership.role)
      else
        false
      end
    end

    def same_workspace?(membership)
      membership.workspace_id == workspace.id
    end

    def sole_owner?(membership)
      membership.owner? && workspace.memberships.owner.where.not(id: membership.id).none?
    end

    def success
      Result.new(success: true)
    end

    def failure(error)
      Result.new(success: false, error:)
    end
end
