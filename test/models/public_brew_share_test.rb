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
    assert_equal Digest::SHA256.hexdigest(share.token), share.token_digest
    assert_not share.enabled?
    assert_equal({}, share.snapshot)
  end

  test "finds enabled shares by token digest" do
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_equal share, PublicBrewShare.find_enabled_by_token!(share.token)
    assert_raises(ActiveRecord::RecordNotFound) { PublicBrewShare.find_enabled_by_token!("wrong") }
  end

  test "requires espresso brew" do
    quick_drip = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 30,
      taste_balance: "neutral"
    )
    share = PublicBrewShare.new(
      workspace: quick_drip.workspace,
      brew: quick_drip,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_not share.valid?
    assert_includes share.errors[:brew], "must be an espresso brew"
  end

  test "enabled token lookup ignores stale quick drip shares" do
    quick_drip = workspaces(:household).brews.create!(
      user: users(:one),
      method: "quick_drip",
      bean: beans(:second_open_household),
      brewer: equipment(:household_brewer),
      machine_cups: 6,
      bean_weight_grams: 30,
      taste_balance: "neutral"
    )
    share = PublicBrewShare.create!(
      workspace: workspaces(:household),
      brew: brews(:morning_espresso),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )
    share.update_columns(brew_id: quick_drip.id)

    assert_raises(ActiveRecord::RecordNotFound) { PublicBrewShare.find_enabled_by_token!(share.token) }
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

  test "legacy public attachment ids are limited to selected public share records" do
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

  test "public attachment ids prefer the curated media manifest when present" do
    brew = brews(:morning_espresso)
    selected_photo = attach_photo(brew)
    rogue_photo = attach_photo(beans(:other_workspace_open))
    share = PublicBrewShare.create!(
      workspace: brew.workspace,
      brew:,
      created_by: users(:one),
      updated_by: users(:one),
      selected_photo_attachment_ids: [ selected_photo.id ],
      snapshot: {
        "public_media" => [ { "attachment_id" => selected_photo.id } ],
        "photos" => [
          { "attachment_id" => selected_photo.id },
          { "attachment_id" => rogue_photo.id }
        ]
      }
    )

    assert_equal [ selected_photo.id ], share.public_attachment_ids
  end

  test "public media handles are opaque and resolve only for snapshot attachments" do
    brew = brews(:morning_espresso)
    photo = attach_photo(brew)
    share = PublicBrewShare.create!(
      workspace: brew.workspace,
      brew:,
      created_by: users(:one),
      updated_by: users(:one),
      snapshot: {
        "public_media" => [ { "attachment_id" => photo.id } ],
        "photos" => [ { "attachment_id" => photo.id } ]
      }
    )

    handle = share.public_media_handle_for(photo.id)

    assert handle.present?
    assert_not_equal photo.id.to_s, handle
    assert_equal photo.id, share.public_attachment_id_for_media_handle(handle)
    assert_nil share.public_media_handle_for(999_999)
    assert_nil share.public_attachment_id_for_media_handle(photo.id.to_s)
  end
end
