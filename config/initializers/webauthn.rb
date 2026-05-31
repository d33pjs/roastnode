origin = ENV["ROASTNODE_WEBAUTHN_ORIGIN"].presence

if origin.blank?
  raise "ROASTNODE_WEBAUTHN_ORIGIN is required in production" if Rails.env.production?

  origin = "http://localhost:3001"
end

WebAuthn.configure do |config|
  config.rp_name = "Roastnode"
  config.allowed_origins = origin.split(",").map(&:strip).compact_blank

  rp_id = ENV["ROASTNODE_WEBAUTHN_RP_ID"].presence
  config.rp_id = rp_id if rp_id
end
