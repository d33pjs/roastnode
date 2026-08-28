# Be sure to restart your server when you modify this file.

# Configure parameters, including cupping bearer tokens/media handles, to be partially matched and filtered from logs.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :media_id, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :webauthn, :credential, :raw_id, :client_data_json, :attestation_object, :authenticator_data, :signature,
  :user_handle, :public_key, :feedback_comment, :recipient_name, :metadata
]
