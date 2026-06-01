require "test_helper"

class PublicBrewShareTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "generates token and starts disabled" do
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one),
      title: "Morning shot"
    )

    assert share.token.present?
    assert_not share.enabled?
    assert_equal({}, share.snapshot)
  end

  test "optional password protection works" do
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one),
      password: "espresso"
    )

    assert share.password_protected?
    assert share.authenticate_password("espresso")
    assert_not share.authenticate_password("wrong")
  end

  test "password cannot exceed bcrypt limit" do
    share = PublicBrewShare.new(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one),
      password: "x" * 73
    )

    assert_not share.valid?
    assert_includes share.errors[:password], "is too long (maximum is 72 characters)"
  end

  test "only one public share can exist for a brew" do
    brew = brews(:morning_espresso)
    PublicBrewShare.create!(
      workspace: brew.workspace,
      brew:,
      created_by: users(:one),
      updated_by: users(:one)
    )
    duplicate = PublicBrewShare.new(
      workspace: brew.workspace,
      brew:,
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:brew_id], "has already been taken"
  end

  test "writer can manage own brew share but not another writer brew share" do
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:one))
    assert_not share.manageable_by?(users(:two))
  end

  test "workspace admin can manage any workspace share" do
    memberships(:member).update!(role: "admin")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:two))
  end

  test "viewer cannot manage shares" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not share.manageable_by?(users(:two))
  end

  test "public attachment ids are limited to selected public share records" do
    brew = brews(:morning_espresso)
    logo = attach_named_photo(brew.workspace, :logo, filename: "workspace-logo.jpg")
    avatar = attach_named_photo(brew.user, :avatar, filename: "avatar.jpg")
    brew_photo = attach_photo(brew)
    bean_photo = attach_photo(brew.bean)
    unselected_photo = attach_photo(brew.bean)
    unrelated_photo = attach_photo(beans(:other_workspace_open))
    share = PublicBrewShare.create!(
      workspace: brew.workspace,
      brew:,
      created_by: users(:one),
      updated_by: users(:one),
      selected_photo_attachment_ids: [ brew_photo.id, bean_photo.id, unrelated_photo.id ],
      snapshot: {
        "workspace" => { "logo_attachment_id" => logo.id },
        "user" => { "avatar_attachment_id" => avatar.id },
        "photos" => [
          { "attachment_id" => brew_photo.id },
          { "attachment_id" => unselected_photo.id },
          { "attachment_id" => unrelated_photo.id },
          { "attachment_id" => 999_999 }
        ],
        "sections" => [
          { "photo_attachment_id" => bean_photo.id }
        ]
      }
    )

    assert_equal [ avatar.id, bean_photo.id, brew_photo.id, logo.id ].sort, share.public_attachment_ids.sort
  end
end
