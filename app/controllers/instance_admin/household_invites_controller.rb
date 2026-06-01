module InstanceAdmin
  class HouseholdInvitesController < ApplicationController
    before_action :authorize_instance_admin!
    before_action :set_household_invite, only: %i[revoke resend reinvite]

    def create
      invite = HouseholdInvite.new(household_invite_params.merge(created_by: Current.user))

      unless invite.save
        return redirect_to instance_admin_path, alert: invite.errors.full_messages.to_sentence
      end

      unless deliver_invite_later(invite)
        return redirect_to instance_admin_path, alert: t(".delivery_failed")
      end

      redirect_to instance_admin_path, notice: t(".created_and_sent")
    end

    def revoke
      unless @household_invite.acceptable?
        return redirect_to instance_admin_path, alert: t(".unavailable")
      end

      @household_invite.revoke!

      redirect_to instance_admin_path, notice: t(".revoked")
    end

    def resend
      unless @household_invite.acceptable?
        return redirect_to instance_admin_path, alert: t(".unavailable")
      end

      unless deliver_invite_later(@household_invite)
        return redirect_to instance_admin_path, alert: t(".delivery_failed")
      end

      redirect_to instance_admin_path, notice: t(".queued")
    end

    def reinvite
      if @household_invite.acceptable?
        return redirect_to instance_admin_path, alert: t(".unavailable")
      end

      fresh_invite = HouseholdInvite.create!(
        email_address: @household_invite.email_address,
        created_by: Current.user
      )

      unless deliver_invite_later(fresh_invite)
        return redirect_to instance_admin_path, alert: t(".delivery_failed")
      end

      redirect_to instance_admin_path, notice: t(".queued")
    end

    private
      def set_household_invite
        @household_invite = HouseholdInvite.find(params[:id])
      end

      def household_invite_params
        params.expect(household_invite: [ :email_address ])
      end

      def deliver_invite_later(household_invite)
        HouseholdInvitesMailer.invite(household_invite).deliver_later
        true
      rescue StandardError => error
        Rails.logger.warn("Household invite mail enqueue failed: #{error.class}: #{safe_error_message(error.message)}")
        false
      end

      def safe_error_message(message)
        message.to_s
          .gsub(/((?:access_)?token|password|secret|session)([\w-]*)?(\s*[:=]\s*)[^\s&]+/i, "\\1\\2\\3[REDACTED]")
          .truncate(220)
      end
  end
end
