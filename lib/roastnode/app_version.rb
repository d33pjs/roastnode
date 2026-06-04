require "open3"

module Roastnode
  class AppVersion
    DEFAULT_GITHUB_URL = "https://github.com/d33pjs/roastnode"
    FALLBACK_VERSION = "development"

    class << self
      def current
        @current ||= env_version || git_tag_version || FALLBACK_VERSION
      end

      def github_url
        ENV.fetch("ROASTNODE_GITHUB_URL", DEFAULT_GITHUB_URL).to_s.strip.presence || DEFAULT_GITHUB_URL
      end

      def reset!
        remove_instance_variable(:@current) if instance_variable_defined?(:@current)
      end

      private
        def env_version
          ENV["ROASTNODE_VERSION"].to_s.strip.presence
        end

        def git_tag_version
          stdout, status = Open3.capture2e("git", "-C", Rails.root.to_s, "describe", "--tags", "--abbrev=0")
          return unless status.success?

          stdout.strip.presence
        rescue StandardError
          nil
        end
    end
  end
end
