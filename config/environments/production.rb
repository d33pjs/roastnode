require "active_support/core_ext/integer/time"
require_relative "../../lib/roastnode/runtime_settings"

runtime_settings = Roastnode::RuntimeSettings.new

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # Trust HTTPS headers from a TLS-terminating reverse proxy when explicitly enabled.
  config.assume_ssl = true if runtime_settings.assume_ssl?

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  if runtime_settings.force_ssl?
    config.force_ssl = true
    config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
  end

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = runtime_settings.default_url_options

  if (smtp_settings = runtime_settings.smtp_settings)
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = smtp_settings
    config.action_mailer.raise_delivery_errors = runtime_settings.smtp_raise_delivery_errors?
  end

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  allowed_hosts = runtime_settings.allowed_hosts
  if allowed_hosts.any?
    config.hosts.concat(allowed_hosts)
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  end
end
