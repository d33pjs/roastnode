require "test_helper"
require "zip"

class WorkspaceMediaArchiveBuilderTest < ActiveSupport::TestCase
  test "builds a workspace scoped media archive with manifest and originals" do
    generated_at = Time.zone.parse("2026-05-27 08:15:00")
    workspace = workspaces(:household)
    bean_photo = attach_photo(beans(:open_household), filename: "bean bag.jpg")
    external_coffee = workspace.external_coffees.create!(user: users(:one), drink_type: "Cortado")
    external_photo = attach_photo(external_coffee, filename: "cafe cup.jpg")
    other_workspace_photo = attach_photo(beans(:other_workspace_open), filename: "other.jpg")
    workspace_logo = attach_one(workspace.logo, filename: "logo.png")

    archive = WorkspaceMediaArchiveBuilder.new(workspace, generated_at:).call
    entries = read_zip_entries(archive)

    assert_includes entries.keys, "manifest.json"
    assert_includes entries.keys, "data/workspace-export.json"

    manifest = JSON.parse(entries.fetch("manifest.json"))
    assert_equal "roastnode.workspace_media_archive", manifest.fetch("format")
    assert_equal 1, manifest.fetch("version")
    assert_equal generated_at.iso8601, manifest.fetch("generated_at")
    assert_equal workspace.id, manifest.fetch("workspace").fetch("id")

    bean_file = manifest.fetch("files").find { |file| file.fetch("attachment_id") == bean_photo.id }
    assert_equal "Bean", bean_file.fetch("record_type")
    assert_equal beans(:open_household).id, bean_file.fetch("record_id")
    assert_equal "photos", bean_file.fetch("attachment_name")
    assert_match %r{\Amedia/beans/#{beans(:open_household).id}/photos/#{bean_photo.id}-bean_bag\.jpg\z}, bean_file.fetch("path")
    assert_equal File.binread(Rails.root.join("test/fixtures/files/photo.jpg")), entries.fetch(bean_file.fetch("path"))

    external_file = manifest.fetch("files").find { |file| file.fetch("attachment_id") == external_photo.id }
    assert_equal "ExternalCoffee", external_file.fetch("record_type")
    assert_equal external_coffee.id, external_file.fetch("record_id")
    assert_match %r{\Amedia/external_coffees/#{external_coffee.id}/photos/#{external_photo.id}-cafe_cup\.jpg\z}, external_file.fetch("path")

    logo_file = manifest.fetch("files").find { |file| file.fetch("attachment_id") == workspace_logo.id }
    assert_equal "Workspace", logo_file.fetch("record_type")
    assert_equal "logo", logo_file.fetch("attachment_name")
    assert_includes entries.keys, logo_file.fetch("path")

    refute_includes manifest.fetch("files").map { |file| file.fetch("attachment_id") }, other_workspace_photo.id
    refute entries.keys.any? { |path| path.include?("other.jpg") }
  end

  private
    def attach_photo(record, filename:)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        record.photos.attach(io: file, filename:, content_type: "image/jpeg")
      end
      record.photos.attachments.last
    end

    def attach_one(attachment, filename:)
      File.open(Rails.root.join("test/fixtures/files/photo.jpg")) do |file|
        attachment.attach(io: file, filename:, content_type: "image/png")
      end
      attachment.attachment
    end

    def read_zip_entries(archive)
      entries = {}
      Zip::File.open_buffer(archive) do |zip|
        zip.each do |entry|
          entries[entry.name] = entry.get_input_stream.read
        end
      end
      entries
    end
end
