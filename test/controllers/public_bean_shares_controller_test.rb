require "test_helper"

class PublicBeanSharesControllerTest < ActionDispatch::IntegrationTest
  test "writer can open new share form for own publishable bean" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    photo = attach_photo(bean)
    sign_in_as(user)

    get new_bean_public_bean_share_path(bean)

    assert_response :success
    assert_select "h1", I18n.t("public_bean_shares.new.title")
    assert_select "input[type=checkbox][name=?]", "public_bean_share[enabled]"
    assert_select "input[name=?]", "public_bean_share[title]"
    assert_select "input[type=password][name=?]", "public_bean_share[password]"
    assert_select "input[type=checkbox][name=?][value=?]", "public_bean_share[selected_photo_attachment_ids][]", photo.id.to_s
  end

  test "writer creates disabled password protected share snapshot" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    bean.update!(public_note: "Public bean note.")
    photo = attach_photo(bean)
    sign_in_as(user)

    assert_difference -> { PublicBeanShare.count }, 1 do
      post bean_public_bean_share_path(bean), params: {
        public_bean_share: {
          enabled: "0",
          title: "Shared bag",
          password: "coffee",
          selected_photo_attachment_ids: [ photo.id ]
        }
      }
    end

    share = bean.reload.public_bean_share
    assert_redirected_to edit_bean_public_bean_share_path(bean)
    assert_equal "Shared bag", share.title
    assert_not share.enabled?
    assert share.password_protected?
    assert_equal [ photo.id ], share.selected_photo_attachment_ids
    assert_equal user, share.created_by
    assert_equal user, share.updated_by
    assert_equal "Public bean note.", share.snapshot.dig("bean", "public_note")
  end

  test "create filters selected photos to bean photos" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    selected_photo = attach_photo(bean)
    unrelated_photo = attach_photo(beans(:other_workspace_open))
    sign_in_as(user)

    post bean_public_bean_share_path(bean), params: {
      public_bean_share: {
        enabled: "0",
        title: "Filtered bag",
        selected_photo_attachment_ids: [ selected_photo.id, unrelated_photo.id ]
      }
    }

    share = bean.reload.public_bean_share
    assert_equal [ selected_photo.id ], share.selected_photo_attachment_ids
    assert_includes share.public_attachment_ids, selected_photo.id
    assert_not_includes share.public_attachment_ids, unrelated_photo.id
  end

  test "stock bean cannot be shared" do
    stock = workspaces(:household).beans.create!(
      name: "Unopened",
      roaster_name: "Shelf",
      bag_size_grams: 250,
      remaining_grams: 250
    )
    sign_in_as(users(:one))

    assert_no_difference -> { PublicBeanShare.count } do
      get new_bean_public_bean_share_path(stock)
    end

    assert_redirected_to bean_path(stock)
    assert_equal I18n.t("public_bean_shares.unsupported_status"), flash[:alert]
  end

  test "finished bean without opened date cannot be shared" do
    bean = workspaces(:household).beans.create!(
      name: "Never Opened Finished",
      roaster_name: "Shelf",
      bag_size_grams: 250,
      remaining_grams: 125
    )
    bean.update_columns(finished_at: Time.current)
    sign_in_as(users(:one))

    assert_no_difference -> { PublicBeanShare.count } do
      get new_bean_public_bean_share_path(bean)
    end

    assert_redirected_to bean_path(bean)
    assert_equal I18n.t("public_bean_shares.unsupported_status"), flash[:alert]
  end

  test "viewer cannot manage public bean shares" do
    memberships(:member).update!(role: "viewer")
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get new_bean_public_bean_share_path(beans(:open_household))

    assert_redirected_to root_path
  end

  test "owner can manage another users bean share" do
    writer = users(:two)
    writer.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    share = create_share_for(bean, user: writer)
    sign_in_as(users(:one))

    get edit_bean_public_bean_share_path(bean)

    assert_response :success
    assert_select "h1", I18n.t("public_bean_shares.edit.title")
    assert_select "input[name=?][value=?]", "public_bean_share[title]", share.title
  end

  test "edit shows public bean share url when enabled" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    share = create_share_for(bean, user:, enabled: true)
    sign_in_as(user)

    get edit_bean_public_bean_share_path(bean)

    assert_response :success
    assert_select "[data-testid=public-bean-share-url] a[href=?]", public_bean_page_path(share.token), text: public_bean_page_url(share.token)
  end

  test "writer cannot manage another writers bean share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    other_writer = User.create!(
      email_address: "other-bean-share-writer@example.com",
      password: "password",
      active_workspace: workspaces(:household)
    )
    Membership.create!(user: other_writer, workspace: workspaces(:household), role: "member")
    create_share_for(beans(:open_household), user: other_writer)
    sign_in_as(user)

    get edit_bean_public_bean_share_path(beans(:open_household))

    assert_redirected_to root_path
  end

  test "update can enable share and clear password" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    share = create_share_for(bean, user:, enabled: false, password: "coffee")
    sign_in_as(user)

    patch bean_public_bean_share_path(bean), params: {
      public_bean_share: {
        enabled: "1",
        title: "Enabled bag",
        password: "",
        clear_password: "1",
        selected_photo_attachment_ids: []
      }
    }

    assert_redirected_to edit_bean_public_bean_share_path(bean)
    share.reload
    assert share.enabled?
    assert_equal "Enabled bag", share.title
    assert_not share.password_protected?
    assert_equal user, share.updated_by
  end

  test "writer can destroy own public bean share" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    bean = beans(:open_household)
    create_share_for(bean, user:)
    sign_in_as(user)

    assert_difference -> { PublicBeanShare.count }, -1 do
      delete bean_public_bean_share_path(bean)
    end

    assert_redirected_to bean_path(bean)
  end

  test "workspace settings removal returns to public bean shares section" do
    bean = beans(:open_household)
    create_share_for(bean, user: users(:one))
    sign_in_as(users(:one))

    assert_difference -> { PublicBeanShare.count }, -1 do
      delete bean_public_bean_share_path(bean), params: { return_to: "public_bean_shares" }
    end

    assert_redirected_to edit_workspace_path(anchor: "public-bean-shares")
  end

  private
    def create_share_for(bean, user:, enabled: true, password: nil, title: "Shared bean")
      bean.create_public_bean_share!(
        workspace: bean.workspace,
        created_by: user,
        updated_by: user,
        enabled:,
        title:,
        password:,
        selected_photo_attachment_ids: [],
        snapshot: PublicBeanShareSnapshotBuilder.new(
          bean:,
          title:,
          selected_photo_attachment_ids: []
        ).call
      )
    end
end
