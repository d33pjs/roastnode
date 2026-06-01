require "test_helper"

class PublicBrewShareTest < ActiveSupport::TestCase
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

  test "public attachment ids are collected from nested snapshot values" do
    share = PublicBrewShare.new(snapshot: {
      "workspace" => { "logo_attachment_id" => 10 },
      "user" => { "avatar_attachment_id" => 11 },
      "photos" => [ { "attachment_id" => 12 } ],
      "sections" => [
        { "photo_attachment_id" => 13, "photos" => [ { "attachment_id" => 14 } ] }
      ]
    })

    assert_equal [ 10, 11, 12, 13, 14 ], share.public_attachment_ids.sort
  end
end
