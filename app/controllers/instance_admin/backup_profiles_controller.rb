module InstanceAdmin
  class BackupProfilesController < ApplicationController
    before_action :authorize_instance_admin!
    before_action :set_profile, only: %i[update run]

    def create
      @profile = InstanceBackupProfile.new(profile_params)
      @profile.name = InstanceBackupProfile.default_name_for(@profile.backup_kind) if @profile.name.blank?

      created = InstanceBackupProfile.transaction do
        next false unless @profile.save

        Activity::Emitter.record!(
          action: "instance_backup_profile.created", workspace: nil,
          actor: Current.user, subject: @profile
        )
        true
      end

      if created
        redirect_to instance_admin_path, notice: t(".created")
      else
        redirect_to instance_admin_path, alert: @profile.errors.full_messages.to_sentence
      end
    end

    def update
      updated = InstanceBackupProfile.transaction do
        next false unless @profile.update(profile_params)

        Activity::Emitter.record!(
          action: "instance_backup_profile.updated", workspace: nil,
          actor: Current.user, subject: @profile
        )
        true
      end

      if updated
        redirect_to instance_admin_path, notice: t(".updated")
      else
        redirect_to instance_admin_path, alert: @profile.errors.full_messages.to_sentence
      end
    end

    def run
      @profile.enqueue_run!(actor: Current.user, track_schedule: false)
      redirect_to instance_admin_path, notice: t(".queued")
    end

    private
      def set_profile
        @profile = InstanceBackupProfile.find(params[:id])
      end

      def profile_params
        params.require(:instance_backup_profile).permit(:backup_kind, :name, :enabled, :schedule, :storage_path, :retention_count)
      end
  end
end
