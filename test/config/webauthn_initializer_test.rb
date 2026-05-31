require "test_helper"

class WebauthnInitializerTest < ActiveSupport::TestCase
  test "blank production origin is rejected" do
    with_env("ROASTNODE_WEBAUTHN_ORIGIN" => "   ") do
      with_rails_env("production") do
        error = assert_raises(RuntimeError) do
          load Rails.root.join("config/initializers/webauthn.rb").to_s
        end

        assert_equal "ROASTNODE_WEBAUTHN_ORIGIN is required in production", error.message
      end
    end
  end

  private
    def with_rails_env(environment)
      original_env = Rails.env
      Rails.singleton_class.define_method(:env) { ActiveSupport::StringInquirer.new(environment) }
      yield
    ensure
      Rails.singleton_class.define_method(:env) { original_env }
    end

    def with_env(values)
      previous_values = values.to_h { |key, _value| [ key, ENV[key] ] }
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      previous_values.each do |key, value|
        value.nil? ? ENV.delete(key) : ENV[key] = value
      end
    end
end
