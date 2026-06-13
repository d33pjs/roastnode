require "test_helper"

class PublicBeanShareTest < ActiveSupport::TestCase
  include PhotoTestHelper

  test "generates token and starts disabled" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      title: "House Blend"
    )

    assert share.token.present?
    assert_equal Digest::SHA256.hexdigest(share.token), share.token_digest
    assert_not share.enabled?
    assert_equal({}, share.snapshot)
  end

  test "finds enabled shares by token digest" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_equal share, PublicBeanShare.find_enabled_by_token!(share.token)
    assert_raises(ActiveRecord::RecordNotFound) { PublicBeanShare.find_enabled_by_token!("wrong") }
  end

  test "does not find disabled shares by token" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      enabled: false
    )

    assert_raises(ActiveRecord::RecordNotFound) { PublicBeanShare.find_enabled_by_token!(share.token) }
  end

  test "requires publishable bean lifecycle" do
    stock = workspaces(:household).beans.create!(
      name: "Stock Bag",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250
    )
    share = PublicBeanShare.new(
      workspace: stock.workspace,
      bean: stock,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_not share.valid?
    assert_includes share.errors[:bean], "must be open, finished, or used up"
  end

  test "requires opened bean lifecycle" do
    finished_without_opened_on = workspaces(:household).beans.create!(
      name: "Never Opened",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 125,
      finished_at: Time.current
    )
    share = PublicBeanShare.new(
      workspace: finished_without_opened_on.workspace,
      bean: finished_without_opened_on,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_not share.valid?
    assert_includes share.errors[:bean], "must be open, finished, or used up"
  end

  test "class publishable bean predicate requires opened publishable lifecycle" do
    stock = workspaces(:household).beans.create!(
      name: "Stock Predicate Bag",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 250
    )
    finished_without_opened_on = workspaces(:household).beans.create!(
      name: "Finished Without Opened Predicate Bag",
      roaster_name: "Shelf Roaster",
      bag_size_grams: 250,
      remaining_grams: 125
    )
    finished_without_opened_on.update_columns(finished_at: Time.current)
    finished = beans(:open_household)
    finished.finish!

    assert_not PublicBeanShare.publishable_bean?(nil)
    assert_not PublicBeanShare.publishable_bean?(stock)
    assert_not PublicBeanShare.publishable_bean?(finished_without_opened_on)
    assert PublicBeanShare.publishable_bean?(finished)
  end

  test "allows finished and used up bags" do
    finished = beans(:open_household)
    finished.finish!
    used_up = beans(:second_open_household)
    used_up.update!(remaining_grams: 0)

    [ finished, used_up ].each do |bean|
      share = PublicBeanShare.new(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one)
      )
      assert share.valid?, share.errors.full_messages.to_sentence
    end
  end

  test "optional password protection works" do
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      password: "espresso"
    )

    assert share.password_protected?
    assert share.authenticate_password("espresso")
    assert_not share.authenticate_password("wrong")
  end

  test "password cannot exceed bcrypt limit" do
    share = PublicBeanShare.new(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one),
      password: "x" * 73
    )

    assert_not share.valid?
    assert_includes share.errors[:password], "is too long (maximum is 72 characters)"
  end

  test "only one public share can exist for a bean" do
    bean = beans(:open_household)
    PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one)
    )
    duplicate = PublicBeanShare.new(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:bean_id], "has already been taken"
  end

  test "member can manage own bean share but not another member share" do
    memberships(:owner).update!(role: "member")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:two),
      updated_by: users(:two)
    )

    assert share.manageable_by?(users(:two))
    assert_not share.manageable_by?(users(:one))
  end

  test "workspace admin can manage any bean share" do
    memberships(:member).update!(role: "admin")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert share.manageable_by?(users(:two))
  end

  test "viewer cannot manage bean shares" do
    memberships(:member).update!(role: "viewer")
    users(:two).update!(active_workspace: workspaces(:household))
    share = PublicBeanShare.create!(
      workspace: workspaces(:household),
      bean: beans(:open_household),
      created_by: users(:one),
      updated_by: users(:one)
    )

    assert_not share.manageable_by?(users(:two))
  end

  test "public attachment ids come only from curated media manifest" do
    bean = beans(:open_household)
    selected_photo = attach_photo(bean)
    rogue_photo = attach_photo(beans(:other_workspace_open))
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
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

  test "public media handles are opaque and resolve only for public attachments" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one),
      snapshot: {
        "public_media" => [ { "attachment_id" => photo.id } ]
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
