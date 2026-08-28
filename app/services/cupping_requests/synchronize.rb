module CuppingRequests
  class Synchronize
    def self.call(brew)
      eligible = brew.persisted? && brew.espresso? && brew.recipient_guest?
      return brew.cupping_request&.destroy! unless eligible

      brew.cupping_request || brew.create_cupping_request!(
        workspace: brew.workspace,
        snapshot: PublicBrewShareSnapshotBuilder.new(
          brew:, title: PublicBrewShare.default_title_for(brew), selected_photo_attachment_ids: []
        ).call
      )
    end
  end
end
