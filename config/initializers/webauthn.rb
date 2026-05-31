allowed_origins = ENV["ROASTNODE_WEBAUTHN_ORIGIN"].to_s.split(",").map(&:strip).compact_blank

if allowed_origins.empty?
  raise "ROASTNODE_WEBAUTHN_ORIGIN is required in production" if Rails.env.production?

  allowed_origins = [ "http://localhost:3001" ]
end

WebAuthn.configure do |config|
  config.rp_name = "Roastnode"
  config.allowed_origins = allowed_origins

  rp_id = ENV["ROASTNODE_WEBAUTHN_RP_ID"].presence
  config.rp_id = rp_id if rp_id
end
