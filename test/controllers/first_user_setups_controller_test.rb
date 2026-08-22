require "test_helper"

class FirstUserSetupsControllerTest < ActionDispatch::IntegrationTest
  setup { clear_instance_records }

  test "empty instance shows setup links on public home and sign in" do
    get root_path
    assert_response :success
    assert_select "a[href=?]", new_first_user_setup_path, text: I18n.t("home.index.setup_first_user")

    get new_session_path
    assert_response :success
    assert_select "a[href=?]", new_first_user_setup_path, text: I18n.t("sessions.new.setup_first_user")
  end

  test "new renders setup form only when no users exist" do
    get new_first_user_setup_path

    assert_response :success
    assert_select "h1", I18n.t("first_user_setups.new.title")
    assert_select "form[action=?]", first_user_setup_path
    assert_select "input[name=?]", "user[email_address]"
    assert_select "input[name=?]", "user[password]"
    assert_select "input[name=?]", "user[password_confirmation]"
  end

  test "create makes the first user an instance admin and signs them in" do
    before_event_ids = ActivityEvent.pluck(:id)
    assert_difference -> { User.count }, 1 do
      post first_user_setup_path, params: {
        user: {
          email_address: "owner@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by!(email_address: "owner@example.com")
    assert_redirected_to root_path
    assert_predicate user, :instance_admin?
    assert user.sessions.exists?
    assert cookies[:session_id].present?
    events = ActivityEvent.where.not(id: before_event_ids).order(:id).to_a
    assert_equal %w[instance.first_user_created session.signed_in], events.map(&:action).sort
    assert_includes events.map(&:action), "instance.first_user_created"
    assert events.all? { |event| event.workspace.nil? && event.actor == user && event.subject == user }
    assert events.all? { |event| event.visibility == "instance_admin" }

    follow_redirect!
    assert_select "h1", I18n.t("workspace_onboardings.new.title")
  end

  test "create rejects invalid user input without creating an account" do
    assert_no_difference -> { User.count } do
      post first_user_setup_path, params: {
        user: {
          email_address: "",
          password: "password",
          password_confirmation: "mismatch"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "h1", I18n.t("first_user_setups.new.title")
  end

  test "setup redirects once any user exists" do
    User.create!(email_address: "existing@example.com", password: "password")

    get new_first_user_setup_path
    assert_redirected_to new_session_path

    assert_no_difference -> { User.count } do
      post first_user_setup_path, params: {
        user: {
          email_address: "second@example.com",
          password: "password",
          password_confirmation: "password"
        }
      }
    end
    assert_redirected_to new_session_path
  end

  private
    def clear_instance_records
      ActiveRecord::Base.connection.disable_referential_integrity do
        [
          ActiveStorage::Attachment,
          ActiveStorage::VariantRecord,
          ActiveStorage::Blob,
          BrewPreparationTool,
          InventoryAdjustment,
          Brew,
          EquipmentEventItem,
          EquipmentEvent,
          Bean,
          Equipment,
          PreparationTool,
          DataImport,
          WorkspaceInvite,
          Membership,
          PasskeyCredential,
          Session,
          Workspace,
          User
        ].each(&:delete_all)
      end
    end
end
