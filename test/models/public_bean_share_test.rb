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
    assert_includes share.errors[:bean], "must be open, finished, used up, or archived after being opened"
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
    assert_includes share.errors[:bean], "must be open, finished, used up, or archived after being opened"
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
    archived = beans(:archived_household)

    assert_not PublicBeanShare.publishable_bean?(nil)
    assert_not PublicBeanShare.publishable_bean?(stock)
    assert_not PublicBeanShare.publishable_bean?(finished_without_opened_on)
    assert PublicBeanShare.publishable_bean?(finished)
    assert PublicBeanShare.publishable_bean?(archived)
  end

  test "allows finished used up and archived bags" do
    finished = beans(:open_household)
    finished.finish!
    used_up = beans(:second_open_household)
    used_up.update!(remaining_grams: 0)
    archived = beans(:archived_household)

    [ finished, used_up, archived ].each do |bean|
      share = PublicBeanShare.new(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one)
      )
      assert share.valid?, share.errors.full_messages.to_sentence
    end
  end

  test "finds enabled archived bean shares by token" do
    bean = beans(:archived_household)
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one),
      enabled: true
    )

    assert_equal share, PublicBeanShare.find_enabled_by_token!(share.token)
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

  test "public attachment ids intersect manifest with live allowed attachments" do
    bean = beans(:open_household)
    selected_photo = attach_photo(bean)
    rogue_photo = attach_photo(beans(:other_workspace_open))
    logo = attach_named_photo(bean.workspace, :logo, filename: "household-logo.jpg")
    avatar = attach_named_photo(users(:one), :avatar, filename: "brewer-avatar.jpg")
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one),
      selected_photo_attachment_ids: [ selected_photo.id ],
      snapshot: {
        "public_media" => [
          { "attachment_id" => selected_photo.id },
          { "attachment_id" => rogue_photo.id },
          { "attachment_id" => logo.id },
          { "attachment_id" => avatar.id }
        ]
      }
    )

    assert_equal [ avatar.id, logo.id, selected_photo.id ].sort, share.public_attachment_ids.sort
    assert_nil share.public_media_handle_for(rogue_photo.id)
  end

  test "recipient avatar remains public only while current workspace membership authorizes it" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, recipient_kind: "household_member", recipient_user: users(:two))
    avatar = attach_named_photo(users(:two), :avatar, filename: "petra-private.jpg")
    share = create_snapshot_share(bean)

    handle = share.public_media_handle_for(avatar.id)
    assert_match(/\A[0-9a-f]{32}\z/, handle)

    memberships(:member).destroy!

    assert_nil share.reload.public_media_handle_for(avatar.id)
  end

  test "repeated logger and recipient handles reuse the complete live authorization graph" do
    bean = beans(:open_household)
    brew = brews(:morning_espresso)
    brew.update!(bean:, recipient_kind: "household_member", recipient_user: users(:two))
    logger_avatar = attach_named_photo(users(:one), :avatar, filename: "logger-private.jpg")
    recipient_avatar = attach_named_photo(users(:two), :avatar, filename: "petra-private.jpg")
    share = create_snapshot_share(bean)
    queries = []
    callback = lambda do |_name, _started, _finished, _unique_id, payload|
      queries << payload[:sql] if payload[:name] != "SCHEMA"
    end

    handles = ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      5.times.flat_map do
        [
          share.public_media_handle_for(logger_avatar.id),
          share.public_media_handle_for(recipient_avatar.id)
        ]
      end
    end

    assert handles.all?(&:present?)
    assert_equal 1, queries.grep(/FROM "memberships"/i).size
    assert_operator queries.grep(/FROM "brews"/i).size, :<=, 2
    assert_operator queries.grep(/FROM "users"/i).size, :<=, 2
    assert_operator queries.grep(/FROM "active_storage_attachments"/i).size, :<=, 3
    assert_operator queries.grep(/FROM "active_storage_blobs"/i).size, :<=, 2

    memberships(:member).destroy!
    assert_nil PublicBeanShare.find(share.id).public_media_handle_for(recipient_avatar.id)
  end

  test "public media handles are opaque and resolve only for public attachments" do
    bean = beans(:open_household)
    photo = attach_photo(bean)
    share = PublicBeanShare.create!(
      workspace: bean.workspace,
      bean:,
      created_by: users(:one),
      updated_by: users(:one),
      selected_photo_attachment_ids: [ photo.id ],
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

  private
    def create_snapshot_share(bean)
      PublicBeanShare.create!(
        workspace: bean.workspace,
        bean:,
        created_by: users(:one),
        updated_by: users(:one),
        enabled: true,
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title: "Shared bean",
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
