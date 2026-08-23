class PublicBrewRecipientProjection
  def initialize(brew:, authorized_recipient_user_ids: nil, recipient_avatar_attachment_ids: nil)
    @brew = brew
    @authorized_recipient_user_ids = authorized_recipient_user_ids
    @recipient_avatar_attachment_ids = recipient_avatar_attachment_ids
  end

  def call
    kind = brew.read_attribute_before_type_cast(:recipient_kind)
    return { "kind" => kind } if %w[self guest].include?(kind)
    return { "kind" => "unknown" } unless kind == "household_member"

    recipient = brew.recipient_user
    return { "kind" => kind } unless recipient

    payload = { "kind" => kind, "display_label" => recipient.display_label }
    return payload unless current_household_member?

    avatar_attachment_id = recipient_avatar_attachment_id(recipient)
    payload["avatar_attachment_id"] = avatar_attachment_id if avatar_attachment_id
    payload
  end

  private
    attr_reader :brew, :authorized_recipient_user_ids, :recipient_avatar_attachment_ids

    def current_household_member?
      if authorized_recipient_user_ids
        authorized_recipient_user_ids.include?(brew.recipient_user_id)
      else
        brew.workspace.memberships.exists?(user_id: brew.recipient_user_id)
      end
    end

    def recipient_avatar_attachment_id(recipient)
      if recipient_avatar_attachment_ids
        recipient_avatar_attachment_ids[brew.recipient_user_id]
      else
        recipient.avatar.attachment&.id
      end
    end
end
