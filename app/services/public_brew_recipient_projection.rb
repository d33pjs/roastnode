class PublicBrewRecipientProjection
  def initialize(brew:)
    @brew = brew
  end

  def call
    kind = brew.read_attribute_before_type_cast(:recipient_kind)
    return { "kind" => kind } if %w[self guest].include?(kind)
    return { "kind" => "unknown" } unless kind == "household_member"

    recipient = brew.recipient_user
    return { "kind" => kind } unless recipient

    payload = { "kind" => kind, "display_label" => recipient.display_label }
    return payload unless brew.workspace.memberships.exists?(user_id: brew.recipient_user_id)

    avatar_attachment_id = recipient.avatar.attachment&.id
    payload["avatar_attachment_id"] = avatar_attachment_id if avatar_attachment_id
    payload
  end

  private
    attr_reader :brew
end
