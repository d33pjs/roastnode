class InstanceReadableExportBuilder
  FORMAT = "roastnode.instance_readable_export"
  VERSION = 1

  def initialize(generated_at: Time.current)
    @generated_at = generated_at
  end

  def call
    {
      format: FORMAT,
      version: VERSION,
      generated_at: timestamp(generated_at),
      users: users_payload,
      workspaces: workspaces_payload,
      instance_activity_events: ActivityEvent.where(workspace_id: nil).order(:id).map { |event| Activity::ExportSerializer.call(event) },
      media_files:
    }
  end

  def media_file_entries
    @media_file_entries ||= ActiveStorage::Attachment.includes(:blob).order(:id).map do |attachment|
      media_file_payload(attachment).merge(attachment:)
    end
  end

  private
    attr_reader :generated_at

    def users_payload
      User.with_attached_avatar.with_attached_public_banner.order(:id).map do |user|
        {
          id: user.id,
          email_address: user.email_address,
          display_name: user.display_name,
          display_label: user.display_label,
          instance_admin: user.instance_admin,
          active_workspace_id: user.active_workspace_id,
          default_landing_screen: user.default_landing_screen,
          default_brew_focus_field: user.default_brew_focus_field,
          hidden_brew_field_names: user.hidden_brew_field_names,
          enabled_brew_methods: user.enabled_brew_methods,
          grams_per_coffee_spoon: decimal(user.grams_per_coffee_spoon),
          number_format: user.number_format,
          time_format: user.time_format,
          theme: user.theme,
          created_at: timestamp(user.created_at),
          updated_at: timestamp(user.updated_at),
          avatar: attachment_payload(user.avatar.attachment),
          public_banner: attachment_payload(user.public_banner.attachment)
        }
      end
    end

    def workspaces_payload
      Workspace.with_attached_logo.with_attached_banner.order(:id).map do |workspace|
        payload = WorkspaceExportBuilder.new(workspace, generated_at:).call
        payload[:workspace] = payload.fetch(:workspace).merge(
          logo: attachment_payload(workspace.logo.attachment),
          banner: attachment_payload(workspace.banner.attachment)
        )
        payload[:data_imports] = data_imports_payload(workspace)
        payload[:workspace_invites] = workspace_invites_payload(workspace)
        payload[:cupping_requests] = cupping_requests_payload(workspace)
        payload
      end
    end

    def cupping_requests_payload(workspace)
      workspace.cupping_requests.order(:id).map do |request|
        {
          id: request.id,
          workspace_id: request.workspace_id,
          brew_id: request.brew_id,
          token: request.token,
          token_digest: request.token_digest,
          snapshot: archived_cupping_snapshot(request),
          feedback_comment: request.feedback_comment,
          opened_at: timestamp(request.opened_at),
          feedback_expires_at: timestamp(request.feedback_expires_at),
          closed_at: timestamp(request.closed_at),
          last_guest_ip: request.last_guest_ip,
          expiration_job_enqueued_at: timestamp(request.expiration_job_enqueued_at),
          expiration_job_enqueueing_at: timestamp(request.expiration_job_enqueueing_at),
          created_at: timestamp(request.created_at),
          updated_at: timestamp(request.updated_at)
        }
      end
    end

    def archived_cupping_snapshot(request)
      snapshot = request.snapshot.deep_dup
      return snapshot unless snapshot.is_a?(Hash) && snapshot["workspace"].is_a?(Hash) &&
        snapshot["user"].is_a?(Hash) && snapshot["public_media"].is_a?(Array)

      workspace_logo_id = request.workspace.logo.attachment&.id
      user_avatar_id = request.brew.user.avatar.attachment&.id
      attachment_id = snapshot["workspace"]["logo_attachment_id"]
      snapshot["workspace"]["logo_attachment_id"] = attachment_id == workspace_logo_id ? attachment_id : nil
      attachment_id = snapshot["user"]["avatar_attachment_id"]
      snapshot["user"]["avatar_attachment_id"] = attachment_id == user_avatar_id ? attachment_id : nil

      allowed_attachment_ids = [ workspace_logo_id, user_avatar_id ].compact
      snapshot["public_media"] = Array(snapshot["public_media"]).select do |media|
        media.is_a?(Hash) && allowed_attachment_ids.include?(media["attachment_id"])
      end
      snapshot
    end

    def data_imports_payload(workspace)
      workspace.data_imports.includes(:user).order(:id).map do |data_import|
        {
          id: data_import.id,
          user_id: data_import.user_id,
          user_email_address: data_import.user.email_address,
          source: data_import.source,
          status: data_import.status,
          summary: data_import.summary,
          warnings: data_import.warnings,
          raw_payload: data_import.raw_payload,
          created_at: timestamp(data_import.created_at),
          updated_at: timestamp(data_import.updated_at)
        }
      end
    end

    def workspace_invites_payload(workspace)
      workspace.workspace_invites.order(:id).map do |invite|
        {
          id: invite.id,
          email_address: invite.email_address,
          role: invite.role,
          created_by_id: invite.created_by_id,
          accepted_by_id: invite.accepted_by_id,
          expires_at: timestamp(invite.expires_at),
          revoked_at: timestamp(invite.revoked_at),
          accepted_at: timestamp(invite.accepted_at),
          created_at: timestamp(invite.created_at),
          updated_at: timestamp(invite.updated_at)
        }
      end
    end

    def media_files
      media_file_entries.map { |entry| entry.except(:attachment) }
    end

    def attachment_payload(attachment)
      return unless attachment

      media_file_payload(attachment)
    end

    def media_file_payload(attachment)
      {
        path: archive_path(attachment),
        record_type: attachment.record_type,
        record_id: attachment.record_id,
        attachment_id: attachment.id,
        attachment_name: attachment.name,
        filename: attachment.blob.filename.to_s,
        content_type: attachment.blob.content_type,
        byte_size: attachment.blob.byte_size,
        checksum: attachment.blob.checksum,
        created_at: timestamp(attachment.created_at)
      }
    end

    def archive_path(attachment)
      [
        "media",
        attachment.record.model_name.collection,
        attachment.record_id,
        attachment.name,
        "#{attachment.id}-#{safe_filename(attachment.blob.filename.to_s)}"
      ].join("/")
    end

    def safe_filename(filename)
      sanitized = File.basename(filename).gsub(/[^A-Za-z0-9._-]+/, "_").sub(/\A[.]+/, "")
      sanitized.presence || "attachment"
    end

    def timestamp(value)
      value&.iso8601
    end

    def decimal(value)
      value&.to_s("F")
    end
end
