class InstanceUserSnapshot
  Row = Data.define(:id, :display_label, :email_address, :workspace_count, :instance_admin)

  def rows
    User.includes(:memberships).order(:email_address).map do |user|
      Row.new(
        id: user.id,
        display_label: user.display_label,
        email_address: user.email_address,
        workspace_count: user.memberships.size,
        instance_admin: user.instance_admin?
      )
    end
  end
end
