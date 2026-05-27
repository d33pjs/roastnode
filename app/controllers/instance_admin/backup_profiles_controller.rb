module InstanceAdmin
  class BackupProfilesController < ApplicationController
    before_action :authorize_instance_admin!
    before_action :set_profile, only: %i[update run]

    def create
      @profile = InstanceBackupProfile.new(profile_params)
      @profile.name = InstanceBackupProfile.default_name_for(@profile.backup_kind) if @profile.name.blank?

      if @profile.save
        redirect_to instance_admin_path, notice: t(".created")
      else
        redirect_to instance_admin_path, alert: @profile.errors.full_messages.to_sentence
      end
    end

    def update
      if @profile.update(profile_params)
        redirect_to instance_admin_path, notice: t(".updated")
      else
        redirect_to instance_admin_path, alert: @profile.errors.full_messages.to_sentence
      end
    end

    def run
      @profile.enqueue_run!(track_schedule: false)
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
