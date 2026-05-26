require "test_helper"

class MediaAttachmentsControllerTest < ActionDispatch::IntegrationTest
  test "serves active workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:open_household))

    get media_attachment_path(attachment)

    assert_response :success
    assert_equal "image/jpeg", response.media_type
  end

  test "does not serve another workspace attachment" do
    sign_in_as(users(:one))
    attachment = attach_photo(beans(:other_workspace_open))

    get media_attachment_path(attachment)

    assert_response :not_found
  end

end
