# Redact public share bearer tokens and media handles from Rails request logs.
module RoastnodePublicBrewShareLogFilter
  PUBLIC_SHARE_MEDIA_PATH = %r{\A/([sr])/[^/?#]+/media/[^/?#]+}
  PUBLIC_SHARE_PATH = %r{\A/([sr])/[^/?#]+}

  def filtered_path
    redacted_path = super.sub(PUBLIC_SHARE_MEDIA_PATH, '/\1/[FILTERED]/media/[FILTERED]')
    redacted_path.sub(PUBLIC_SHARE_PATH, '/\1/[FILTERED]')
  end
end

ActionDispatch::Request.prepend(RoastnodePublicBrewShareLogFilter)

Rails.application.config.filter_redirect += [
  %r{\A(?:https?://[^/]+)?/[sr]/[^/?#]+}
]
