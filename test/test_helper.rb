ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/activity_event_test_helper"
require_relative "test_helpers/passkey_test_helper"
require_relative "test_helpers/singleton_method_stub_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    setup :clear_action_controller_cache_store
    teardown :clear_action_controller_cache_store

    # Add more helper methods to be used by all tests here...
    include PasskeyTestHelper
    include SingletonMethodStubTestHelper

    private
      def clear_action_controller_cache_store
        ActionController::Base.cache_store&.clear
      end
  end
end

module PhotoTestHelper
  def photo_upload(filename: "photo.jpg")
    fixture_file_upload("photo.jpg", "image/jpeg", filename:)
  end

  def attach_photo(record)
    File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
      record.photos.attach(io: file, filename: "photo.jpg", content_type: "image/jpeg")
    end
    record.photos.attachments.last
  end

  def attach_named_photo(record, attachment_name, filename: "photo.jpg")
    File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
      record.public_send(attachment_name).attach(io: file, filename:, content_type: "image/jpeg")
    end
    record.public_send(attachment_name).attachment
  end
end

class ActionDispatch::IntegrationTest
  include PhotoTestHelper
end
