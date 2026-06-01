require "test_helper"
require "roastnode/runtime_settings"

class Roastnode::RuntimeSettingsTest < ActiveSupport::TestCase
  test "builds public url options from roastnode host protocol and port" do
    settings = Roastnode::RuntimeSettings.new(
      "ROASTNODE_HOST" => "coffee.example.test",
      "ROASTNODE_PROTOCOL" => "https",
      "ROASTNODE_PORT" => "8443"
    )

    assert_equal({ host: "coffee.example.test", protocol: "https", port: 8443 }, settings.default_url_options)
  end

  test "combines explicit allowed hosts with public host" do
    settings = Roastnode::RuntimeSettings.new(
      "ROASTNODE_HOST" => "coffee.example.test",
      "ROASTNODE_ALLOWED_HOSTS" => "coffee.lan, roastnode.local"
    )

    assert_equal [ "coffee.example.test", "coffee.lan", "roastnode.local" ], settings.allowed_hosts
  end

  test "parses ssl and smtp settings" do
    settings = Roastnode::RuntimeSettings.new(
      "RAILS_ASSUME_SSL" => "true",
      "RAILS_FORCE_SSL" => "1",
      "SMTP_ENABLED" => "true",
      "SMTP_ADDRESS" => "smtp.example.test",
      "SMTP_PORT" => "587",
      "SMTP_DOMAIN" => "example.test",
      "SMTP_USER_NAME" => "mailer",
      "SMTP_PASSWORD" => "secret",
      "SMTP_AUTHENTICATION" => "plain",
      "SMTP_ENABLE_STARTTLS_AUTO" => "false"
    )

    assert settings.assume_ssl?
    assert settings.force_ssl?
    assert_equal(
      {
        address: "smtp.example.test",
        port: 587,
        domain: "example.test",
        user_name: "mailer",
        password: "secret",
        authentication: :plain,
        enable_starttls_auto: false
      },
      settings.smtp_settings
    )
  end

  test "exposes explicit smtp from address" do
    settings = Roastnode::RuntimeSettings.new(
      "SMTP_FROM_ADDRESS" => "Roastnode <invites@coffee.example.test>"
    )

    assert_equal "Roastnode <invites@coffee.example.test>", settings.mail_from_address
  end

  test "derives smtp from address from smtp domain when explicit address is missing" do
    settings = Roastnode::RuntimeSettings.new(
      "SMTP_DOMAIN" => "coffee.example.test"
    )

    assert_equal "no-reply@coffee.example.test", settings.mail_from_address
  end

  test "keeps smtp disabled unless explicitly enabled" do
    settings = Roastnode::RuntimeSettings.new(
      "SMTP_ADDRESS" => "smtp.example.test"
    )

    assert_nil settings.smtp_settings
  end

  test "exposes optional puma ssl settings" do
    settings = Roastnode::RuntimeSettings.new(
      "PUMA_SSL_CERT_PATH" => "/run/secrets/roastnode.crt",
      "PUMA_SSL_KEY_PATH" => "/run/secrets/roastnode.key",
      "PUMA_BIND_HOST" => "0.0.0.0",
      "PORT" => "3443"
    )

    assert settings.puma_ssl?
    assert_equal "/run/secrets/roastnode.crt", settings.puma_ssl_cert_path
    assert_equal "/run/secrets/roastnode.key", settings.puma_ssl_key_path
    assert_equal "0.0.0.0", settings.puma_bind_host
    assert_equal 3443, settings.puma_port
  end

  test "exposes backup defaults" do
    settings = Roastnode::RuntimeSettings.new(
      "ROASTNODE_BACKUP_STORAGE_PATH" => "storage/nightly",
      "ROASTNODE_BACKUP_RETENTION_COUNT" => "14"
    )

    assert_equal "storage/nightly", settings.backup_storage_path
    assert_equal 14, settings.backup_retention_count
  end
end
