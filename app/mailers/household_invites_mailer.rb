class HouseholdInvitesMailer < ApplicationMailer
  def invite(household_invite)
    @household_invite = household_invite

    mail(
      subject: t(".subject"),
      to: @household_invite.email_address
    )
  end
end
