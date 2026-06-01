module Roastnode
  class RuntimeSettings
    TRUE_VALUES = %w[1 true yes on].freeze
    FALSE_VALUES = %w[0 false no off].freeze
    DEFAULT_PUBLIC_HOST = "example.com"
    DEFAULT_MAIL_FROM_ADDRESS = "from@example.com"
    DEFAULT_BACKUP_STORAGE_PATH = "storage/instance_backups"
    DEFAULT_BACKUP_RETENTION_COUNT = 7

    def initialize(env = ENV)
      @env = env
    end

    def default_url_options
      { host: public_host, protocol: public_protocol }.tap do |options|
        options[:port] = public_port if public_port
      end
    end

    def public_host
      fetch("ROASTNODE_HOST", default: DEFAULT_PUBLIC_HOST)
    end

    def public_protocol
      fetch("ROASTNODE_PROTOCOL", default: default_protocol)
    end

    def public_port
      integer("ROASTNODE_PORT")
    end

    def allowed_hosts
      ([ value("ROASTNODE_HOST") ] + csv("ROASTNODE_ALLOWED_HOSTS")).compact.uniq
    end

    def assume_ssl?
      boolean("RAILS_ASSUME_SSL")
    end

    def force_ssl?
      boolean("RAILS_FORCE_SSL")
    end

    def smtp_settings
      return unless boolean("SMTP_ENABLED")

      address = value("SMTP_ADDRESS")
      return unless address

      {
        address:,
        port: integer("SMTP_PORT", default: 587),
        domain: value("SMTP_DOMAIN"),
        user_name: value("SMTP_USER_NAME"),
        password: value("SMTP_PASSWORD"),
        authentication: smtp_authentication,
        enable_starttls_auto: boolean("SMTP_ENABLE_STARTTLS_AUTO", default: true),
        openssl_verify_mode: value("SMTP_OPENSSL_VERIFY_MODE")
      }.compact
    end

    def smtp_raise_delivery_errors?
      boolean("SMTP_RAISE_DELIVERY_ERRORS", default: true)
    end

    def mail_from_address
      fetch("SMTP_FROM_ADDRESS", default: derived_mail_from_address)
    end

    def puma_ssl?
      !!(puma_ssl_cert_path && puma_ssl_key_path)
    end

    def puma_ssl_cert_path
      value("PUMA_SSL_CERT_PATH")
    end

    def puma_ssl_key_path
      value("PUMA_SSL_KEY_PATH")
    end

    def puma_bind_host
      fetch("PUMA_BIND_HOST", default: "0.0.0.0")
    end

    def puma_port
      integer("PORT", default: 3000)
    end

    def backup_storage_path
      fetch("ROASTNODE_BACKUP_STORAGE_PATH", default: DEFAULT_BACKUP_STORAGE_PATH)
    end

    def backup_retention_count
      positive_integer("ROASTNODE_BACKUP_RETENTION_COUNT", default: DEFAULT_BACKUP_RETENTION_COUNT)
    end

    private
      attr_reader :env

      def default_protocol
        assume_ssl? || force_ssl? ? "https" : "http"
      end

      def smtp_authentication
        authentication = value("SMTP_AUTHENTICATION")
        authentication&.to_sym
      end

      def derived_mail_from_address
        smtp_domain = value("SMTP_DOMAIN")
        return "no-reply@#{smtp_domain}" if smtp_domain

        DEFAULT_MAIL_FROM_ADDRESS
      end

      def value(name)
        raw_value = env[name]
        return if raw_value.nil?

        raw_value.to_s.strip.then { |string| string unless string.empty? }
      end

      def fetch(name, default:)
        value(name) || default
      end

      def csv(name)
        value(name).to_s.split(",").map(&:strip).reject(&:empty?)
      end

      def integer(name, default: nil)
        raw_value = value(name)
        return default unless raw_value

        Integer(raw_value)
      rescue ArgumentError
        default
      end

      def positive_integer(name, default:)
        parsed = integer(name, default:)
        parsed.positive? ? parsed : default
      end

      def boolean(name, default: false)
        raw_value = value(name)
        return default if raw_value.nil?

        normalized = raw_value.downcase
        return true if TRUE_VALUES.include?(normalized)
        return false if FALSE_VALUES.include?(normalized)

        default
      end
  end
end
