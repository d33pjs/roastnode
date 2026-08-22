class BrewRecipientPresenter
  def initialize(brew:, workspace:)
    @brew = brew
    @workspace = workspace
  end

  def badge_text = I18n.t("brews.recipients.badge", recipient: recipient_label)

  def recipient_label
    return I18n.t("brews.recipients.me") if brew.recipient_self?
    return brew.recipient_user.display_label if brew.recipient_household_member?

    brew.recipient_name.presence || I18n.t("brews.recipients.a_guest")
  end

  def byline_text
    recipient = brew.recipient_self? ? I18n.t("brews.recipients.themself") : recipient_label
    I18n.t("brews.recipients.byline", logger: brew.user.display_label, recipient:)
  end

  def icon_name
    { "self" => "person", "household_member" => "home", "guest" => "groups" }.fetch(brew.recipient_kind)
  end

  def badge_classes
    {
      "self" => "bg-sky-100/95 text-sky-900 ring-sky-200",
      "household_member" => "bg-orange-100/95 text-orange-900 ring-orange-200",
      "guest" => "bg-emerald-100/95 text-emerald-900 ring-emerald-200"
    }.fetch(brew.recipient_kind)
  end

  def logger_avatar_attachment
    return @logger_avatar_attachment if defined?(@logger_avatar_attachment)

    @logger_avatar_attachment = authorized_avatar(brew.user)
  end

  def recipient_avatar_attachment
    return @recipient_avatar_attachment if defined?(@recipient_avatar_attachment)

    @recipient_avatar_attachment = brew.recipient_household_member? ? authorized_avatar(brew.recipient_user) : nil
  end

  private
    attr_reader :brew, :workspace

    def authorized_avatar(user)
      return unless user && workspace_member_ids.include?(user.id)

      user.avatar.attachment if user.avatar.attached?
    end

    def workspace_member_ids
      @workspace_member_ids ||= workspace.memberships.load.map(&:user_id)
    end
end
