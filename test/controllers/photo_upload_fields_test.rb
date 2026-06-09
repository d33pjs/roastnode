require "test_helper"

class PhotoUploadFieldsTest < ActionDispatch::IntegrationTest
  test "image upload controls use the shared photo upload treatment" do
    sign_in_as(users(:one))

    {
      new_brew_path => "brew[photos][]",
      new_external_coffee_path => "external_coffee[photos][]",
      new_bean_path => "bean[photos][]",
      new_equipment_path => "equipment[photos][]",
      new_preparation_tool_path => "preparation_tool[photos][]",
      new_equipment_event_path => "equipment_event[photos][]",
      new_recipe_path(source_brew_id: brews(:morning_espresso).id) => "recipe[photos]",
      edit_profile_path => "user[avatar]",
      edit_workspace_path => "workspace[logo]"
    }.each do |path, field_name|
      get path

      assert_response :success
      assert_select "input[type=file][name=?][data-testid=photo-upload-input].rn-photo-upload-input", field_name
    end
  end
end
