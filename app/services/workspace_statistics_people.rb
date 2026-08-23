class WorkspaceStatisticsPeople
  RECIPIENT_SELF = "self"
  RECIPIENT_GUESTS = "guests"
  USER_RECIPIENT_PATTERN = /\Auser:(\d+)\z/

  def initialize(workspace:)
    @workspace = workspace
  end

  def logger_users
    @logger_users ||= users_for(
      current_user_ids | workspace.brews.distinct.pluck(:user_id)
    )
  end

  def recipient_users
    @recipient_users ||= users_for(
      current_user_ids |
        workspace.brews.where(recipient_kind: "self").distinct.pluck(:user_id) |
        workspace.brews
          .where(recipient_kind: "household_member")
          .where.not(recipient_user_id: nil)
          .distinct
          .pluck(:recipient_user_id)
    )
  end

  def resolve_logger_id(value)
    return nil if value.nil?
    raise ActiveRecord::RecordNotFound unless value.is_a?(String)
    return nil if value.blank?

    id = Integer(value, 10)
    return id if logger_users.any? { |user| user.id == id }

    raise ActiveRecord::RecordNotFound
  rescue ArgumentError, TypeError
    raise ActiveRecord::RecordNotFound
  end

  def resolve_recipient_filter(value)
    return nil if value.nil?
    raise ActiveRecord::RecordNotFound unless value.is_a?(String)
    return nil if value.blank?
    return value if [ RECIPIENT_SELF, RECIPIENT_GUESTS ].include?(value)

    match = USER_RECIPIENT_PATTERN.match(value)
    raise ActiveRecord::RecordNotFound unless match

    id = match[1].to_i
    raise ActiveRecord::RecordNotFound unless recipient_users.any? { |user| user.id == id }

    "user:#{id}"
  end

  private
    attr_reader :workspace

    def current_user_ids
      @current_user_ids ||= workspace.users.distinct.pluck(:id)
    end

    def users_for(ids)
      User.where(id: ids.compact.uniq).to_a.sort_by do |user|
        [ user.display_label.downcase, user.id ]
      end
    end
end
