module CuppingRequests
  class Synchronize
    def self.call(brew)
      eligible = brew.persisted? && brew.espresso? && brew.recipient_guest?
      unless eligible
        request = brew.cupping_request
        return unless request

        request.destroy!
        brew.association(:cupping_request).reset
        return
      end

      brew.cupping_request || brew.create_cupping_request!(
        workspace: brew.workspace,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:, title: PublicBrewShare.default_title_for(brew), selected_photo_attachment_ids: []
        ).call
      )
    end
  end
end
