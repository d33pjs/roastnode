require "test_helper"

class BeanconquerorImportsControllerTest < ActionDispatch::IntegrationTest
  test "workspace manager sees import form" do
    sign_in_as(users(:one))

    get new_beanconqueror_import_path

    assert_response :success
    assert_select "h1", I18n.t("beanconqueror_imports.new.title")
    assert_select "input[type=file][name=?]", "beanconqueror_import[file]"
  end

  test "workspace manager uploads import and sees report" do
    sign_in_as(users(:one))

    assert_difference -> { workspaces(:household).data_imports.count }, 1 do
      post beanconqueror_imports_path, params: {
        beanconqueror_import: {
          file: fixture_file_upload("beanconqueror_export.json", "application/json")
        }
      }
    end

    import = workspaces(:household).data_imports.order(:created_at).last
    assert_redirected_to beanconqueror_import_path(import)

    follow_redirect!
    assert_response :success
    assert_select "h1", I18n.t("beanconqueror_imports.show.title")
    assert_select "p", text: /completed/
    assert_select "td", text: "beans"
    assert_select "td", text: "1"
  end

  test "member cannot import" do
    user = users(:two)
    user.update!(active_workspace: workspaces(:household))
    sign_in_as(user)

    get new_beanconqueror_import_path

    assert_redirected_to root_path
  end

  test "show is scoped to active workspace" do
    sign_in_as(users(:one))
    import = DataImport.create!(
      workspace: workspaces(:other_household),
      user: users(:two),
      source: "beanconqueror",
      status: "completed"
    )

    get beanconqueror_import_path(import)

    assert_response :not_found
  end
end
