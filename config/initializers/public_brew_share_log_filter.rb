# Redact bearer-token URLs and public media handles from Rails request logs.
module RoastnodeBearerUrlLogFilter
  PUBLIC_SHARE_MEDIA_PATH = %r{\A/([srb])/[^/?#]+/media/[^/?#]+}
  PUBLIC_SHARE_PATH = %r{\A/([srb])/[^/?#]+}
  SENSITIVE_TOKEN_PATH = %r{\A/(passwords|workspace_invites|household_invites)/[^/?#]+}

  def filtered_path
    redacted_path = super.sub(PUBLIC_SHARE_MEDIA_PATH, '/\1/[FILTERED]/media/[FILTERED]')
    redacted_path = redacted_path.sub(PUBLIC_SHARE_PATH, '/\1/[FILTERED]')
    redacted_path.sub(SENSITIVE_TOKEN_PATH, '/\1/[FILTERED]')
  end
end

ActionDispatch::Request.prepend(RoastnodeBearerUrlLogFilter)

Rails.application.config.filter_redirect += [
  %r{\A(?:https?://[^/]+)?/[srb]/[^/?#]+},
  %r{\A(?:https?://[^/]+)?/(?:passwords|workspace_invites|household_invites)/[^/?#]+}
]
