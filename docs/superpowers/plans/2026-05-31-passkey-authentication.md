# Passkey Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add browser-picker passkey login, optional per-user passkey second factor, and password-reset recovery to Roastnode.

**Architecture:** Keep the existing Rails `User` and `Session` authentication boundary. Add user-owned `PasskeyCredential` records, WebAuthn ceremony services, small controllers for registration/login/second-factor verification, and one Stimulus controller for browser WebAuthn calls. Password login remains available unless the signed-in user enabled passkey second factor.

**Tech Stack:** Rails 8.1, Minitest, PostgreSQL, Hotwire/Turbo, Stimulus, importmap, `webauthn` Ruby gem.

---

## Scope Check

This is one authentication subsystem with three connected flows: registration, browser-picker login, and password-plus-passkey second factor. Keep it in one plan so recovery, session creation, and WebAuthn challenge handling stay consistent.

## File Structure

- Create `db/migrate/20260531213000_add_passkey_authentication.rb`: passkey credential table and user flags.
- Modify `Gemfile`: add the `webauthn` gem.
- Create `config/initializers/webauthn.rb`: relying-party name, allowed origins, optional RP ID.
- Modify `config/initializers/filter_parameter_logging.rb`: redact WebAuthn payload fields.
- Modify `app/models/user.rb`: passkey association, stable WebAuthn user handle helper, second-factor validation.
- Create `app/models/passkey_credential.rb`: credential ownership and validation.
- Create `app/controllers/concerns/passkey_challenges.rb`: session-backed 10-minute challenge and pending-login helpers.
- Create `app/services/passkeys/options.rb`: WebAuthn create/get options JSON with discoverable credentials and user verification.
- Create `app/services/passkeys/registration.rb`: verify registration response and persist credential.
- Create `app/services/passkeys/assertion.rb`: verify login/second-factor assertions and update credential metadata.
- Create `app/controllers/passkey_credentials_controller.rb`: signed-in passkey management.
- Create `app/controllers/passkey_sessions_controller.rb`: unauthenticated passkey login.
- Create `app/controllers/passkey_second_factors_controller.rb`: pending password-login second factor.
- Modify `app/controllers/sessions_controller.rb`: branch password login to second-factor challenge when enabled.
- Modify `app/controllers/passwords_controller.rb`: password reset disables passkey second factor.
- Modify `config/routes.rb`: passkey management, login, and second-factor routes.
- Create `app/javascript/controllers/passkey_controller.js`: native browser WebAuthn calls.
- Modify `app/views/sessions/new.html.erb`: passkey login button.
- Create `app/views/passkey_second_factors/show.html.erb`: second-factor verification screen.
- Modify `app/views/profiles/edit.html.erb`: passkey account-security section.
- Create `app/views/profiles/_passkeys.html.erb`: passkey list, add form, second-factor toggle, delete forms.
- Modify `config/locales/en.yml`: passkey UI and flash strings.
- Create `test/fixtures/passkey_credentials.yml`: credential fixture.
- Create `test/test_helpers/passkey_test_helper.rb`: fake WebAuthn options and credentials for controller tests.
- Modify `test/test_helper.rb`: include the passkey test helper.
- Create `test/models/passkey_credential_test.rb`: model coverage.
- Modify `test/models/user_test.rb`: second-factor guardrail coverage.
- Create `test/controllers/passkey_credentials_controller_test.rb`: registration and management coverage.
- Create `test/controllers/passkey_sessions_controller_test.rb`: browser-picker login coverage.
- Create `test/controllers/passkey_second_factors_controller_test.rb`: password-plus-passkey coverage.
- Modify `test/controllers/sessions_controller_test.rb`: password login branching coverage.
- Modify `test/controllers/passwords_controller_test.rb`: recovery behavior coverage.
- Modify `test/controllers/profiles_controller_test.rb`: Profile passkey controls coverage.
- Modify `docs/account-privacy.md`, `docs/setup.md`, `docs/production-self-hosting.md`, and `docs/status.md`: shipped behavior and configuration.

## Task 1: Gem, Schema, Model, And Configuration Foundation

**Files:**
- Modify: `Gemfile`
- Create: `config/initializers/webauthn.rb`
- Modify: `config/initializers/filter_parameter_logging.rb`
- Create: `db/migrate/20260531213000_add_passkey_authentication.rb`
- Modify: `app/models/user.rb`
- Create: `app/models/passkey_credential.rb`
- Create: `test/fixtures/passkey_credentials.yml`
- Create: `test/models/passkey_credential_test.rb`
- Modify: `test/models/user_test.rb`

- [ ] **Step 1: Add failing model tests**

Create `test/models/passkey_credential_test.rb`:

```ruby
require "test_helper"

class PasskeyCredentialTest < ActiveSupport::TestCase
  test "belongs to a user and requires unique external id" do
    credential = PasskeyCredential.new(
      user: users(:one),
      external_id: "credential-unique-test",
      public_key: "public-key",
      sign_count: 0,
      nickname: "MacBook Touch ID"
    )

    assert credential.valid?
    credential.save!

    duplicate = PasskeyCredential.new(
      user: users(:two),
      external_id: "credential-unique-test",
      public_key: "other-public-key",
      sign_count: 0,
      nickname: "Other device"
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:external_id], "has already been taken"
  end

  test "normalizes blank nickname to nil" do
    credential = PasskeyCredential.create!(
      user: users(:one),
      external_id: "credential-blank-nickname",
      public_key: "public-key",
      sign_count: 0,
      nickname: "   "
    )

    assert_nil credential.nickname
  end
end
```

Append these tests to `test/models/user_test.rb`:

```ruby
  test "generates stable webauthn user id on demand" do
    user = users(:one)
    assert_nil user.webauthn_user_id

    generated_id = user.ensure_webauthn_user_id!

    assert generated_id.present?
    assert_equal generated_id, user.reload.webauthn_user_id
    assert_equal generated_id, user.ensure_webauthn_user_id!
  end

  test "passkey second factor requires at least one passkey" do
    user = users(:two)

    user.passkey_second_factor_enabled = true

    assert_not user.valid?
    assert_includes user.errors[:passkey_second_factor_enabled], "requires at least one passkey"
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/models/passkey_credential_test.rb test/models/user_test.rb
```

Expected: FAIL with `uninitialized constant PasskeyCredential` or missing `webauthn_user_id` / `passkey_second_factor_enabled` methods.

- [ ] **Step 3: Add the gem and initializer**

Add this line after the `bcrypt` gem in `Gemfile`:

```ruby
# Verify WebAuthn/passkey registration and assertion ceremonies.
gem "webauthn"
```

Run:

```bash
bundle install
```

Expected: PASS and `Gemfile.lock` includes `webauthn`.

Create `config/initializers/webauthn.rb`:

```ruby
origin = ENV.fetch("ROASTNODE_WEBAUTHN_ORIGIN") do
  raise "ROASTNODE_WEBAUTHN_ORIGIN is required in production" if Rails.env.production?

  "http://localhost:3001"
end

WebAuthn.configure do |config|
  config.rp_name = "Roastnode"
  config.allowed_origins = origin.split(",").map(&:strip).compact_blank

  rp_id = ENV["ROASTNODE_WEBAUTHN_RP_ID"].presence
  config.rp_id = rp_id if rp_id
end
```

Modify `config/initializers/filter_parameter_logging.rb` so the array includes WebAuthn payload fields:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :webauthn, :credential, :raw_id, :client_data_json, :attestation_object, :authenticator_data, :signature,
  :user_handle, :public_key
]
```

- [ ] **Step 4: Add migration and model code**

Create `db/migrate/20260531213000_add_passkey_authentication.rb`:

```ruby
class AddPasskeyAuthentication < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :webauthn_user_id, :string
    add_column :users, :passkey_second_factor_enabled, :boolean, default: false, null: false
    add_index :users, :webauthn_user_id, unique: true

    create_table :passkey_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :external_id, null: false
      t.text :public_key, null: false
      t.bigint :sign_count, default: 0, null: false
      t.string :nickname
      t.datetime :last_used_at
      t.timestamps
    end

    add_index :passkey_credentials, :external_id, unique: true
  end
end
```

Create `app/models/passkey_credential.rb`:

```ruby
class PasskeyCredential < ApplicationRecord
  belongs_to :user

  normalizes :nickname, with: ->(nickname) { nickname.strip.presence }

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :sign_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def display_name
    nickname.presence || "Passkey added #{created_at.to_date.to_fs(:long)}"
  end
end
```

Modify `app/models/user.rb` by adding the association below `has_many :sessions`:

```ruby
  has_many :passkey_credentials, dependent: :destroy
```

Add this validation near the other validations:

```ruby
  validate :passkey_second_factor_requires_passkey
```

Add this public method before `private`:

```ruby
  def ensure_webauthn_user_id!
    return webauthn_user_id if webauthn_user_id.present?

    update!(webauthn_user_id: WebAuthn.generate_user_id)
    webauthn_user_id
  end
```

Add this private validation:

```ruby
    def passkey_second_factor_requires_passkey
      return unless passkey_second_factor_enabled?
      return if passkey_credentials.exists?

      errors.add(:passkey_second_factor_enabled, "requires at least one passkey")
    end
```

Create `test/fixtures/passkey_credentials.yml`:

```yaml
one_touch_id:
  user: one
  external_id: credential-one
  public_key: public-key-one
  sign_count: 0
  nickname: MacBook Touch ID
```

- [ ] **Step 5: Migrate and run model tests**

Run:

```bash
bin/rails db:migrate
bin/rails test test/models/passkey_credential_test.rb test/models/user_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit foundation**

Run:

```bash
git add Gemfile Gemfile.lock config/initializers/webauthn.rb config/initializers/filter_parameter_logging.rb db/migrate/20260531213000_add_passkey_authentication.rb db/schema.rb app/models/user.rb app/models/passkey_credential.rb test/fixtures/passkey_credentials.yml test/models/passkey_credential_test.rb test/models/user_test.rb
git commit -m "feat: add passkey credential foundation"
```

Expected: commit succeeds.

## Task 2: Challenge Storage And WebAuthn Service Boundaries

**Files:**
- Create: `app/controllers/concerns/passkey_challenges.rb`
- Create: `app/services/passkeys/options.rb`
- Create: `app/services/passkeys/registration.rb`
- Create: `app/services/passkeys/assertion.rb`
- Create: `test/test_helpers/passkey_test_helper.rb`
- Modify: `test/test_helper.rb`
- Create: `test/services/passkeys/options_test.rb`

- [ ] **Step 1: Add failing service tests and test helper**

Create `test/test_helpers/passkey_test_helper.rb`:

```ruby
module PasskeyTestHelper
  FakeOptions = Struct.new(:challenge, :payload, keyword_init: true) do
    def to_json(*)
      payload.merge("challenge" => challenge).to_json
    end
  end

  FakeCreatedCredential = Struct.new(:id, :public_key, :sign_count, keyword_init: true) do
    def verify(challenge)
      raise WebAuthn::Error, "missing challenge" if challenge.blank?
      true
    end
  end

  FakeAssertedCredential = Struct.new(:id, :sign_count, keyword_init: true) do
    def verify(challenge, public_key:, sign_count:)
      raise WebAuthn::Error, "missing challenge" if challenge.blank?
      raise WebAuthn::SignCountVerificationError, "stale sign count" if self.sign_count < sign_count
      true
    end
  end

  def fake_options(challenge: nil, payload: {})
    challenge ||= payload["challenge"] || "test-challenge"
    FakeOptions.new(challenge:, payload:)
  end
end
```

Modify `test/test_helper.rb` so it requires the helper after the existing session helper:

```ruby
require_relative "test_helpers/passkey_test_helper"
```

Add this line inside the existing `ActiveSupport::TestCase` class in `test/test_helper.rb`:

```ruby
  include PasskeyTestHelper
```

Create `test/services/passkeys/options_test.rb`:

```ruby
require "test_helper"

class Passkeys::OptionsTest < ActiveSupport::TestCase
  test "registration options require discoverable credentials and user verification" do
    user = users(:one)
    fake = fake_options(
      payload: {
        "challenge" => "test-challenge",
        "user" => { "id" => "user-id", "name" => user.email_address }
      }
    )

    WebAuthn::Credential.stub(:options_for_create, fake) do
      challenge, options = Passkeys::Options.registration_for(user)

      assert_equal "test-challenge", challenge
      assert_equal "required", options.fetch("authenticatorSelection").fetch("residentKey")
      assert_equal true, options.fetch("authenticatorSelection").fetch("requireResidentKey")
      assert_equal "required", options.fetch("authenticatorSelection").fetch("userVerification")
    end
  end

  test "authentication options can force browser account picker" do
    fake = fake_options(payload: { "challenge" => "test-challenge" })

    WebAuthn::Credential.stub(:options_for_get, fake) do
      challenge, options = Passkeys::Options.authentication_for

      assert_equal "test-challenge", challenge
      assert_equal [], options.fetch("allowCredentials")
      assert_equal "required", options.fetch("userVerification")
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/services/passkeys/options_test.rb
```

Expected: FAIL with `uninitialized constant Passkeys::Options`.

- [ ] **Step 3: Add challenge concern and services**

Create `app/controllers/concerns/passkey_challenges.rb`:

```ruby
module PasskeyChallenges
  extend ActiveSupport::Concern

  PASSKEY_CHALLENGE_TTL = 10.minutes

  private
    def store_passkey_challenge(kind, challenge, user_id: nil)
      session[passkey_challenge_key(kind)] = {
        "challenge" => challenge,
        "user_id" => user_id,
        "created_at" => Time.current.iso8601
      }
    end

    def consume_passkey_challenge(kind, user_id: nil)
      payload = session.delete(passkey_challenge_key(kind))
      return unless payload
      return if passkey_challenge_expired?(payload)
      return if user_id.present? && payload["user_id"].to_i != user_id.to_i

      payload["challenge"]
    end

    def store_pending_passkey_user(user)
      session[:pending_passkey_user_id] = user.id
      session[:pending_passkey_user_created_at] = Time.current.iso8601
    end

    def pending_passkey_user
      user_id = session[:pending_passkey_user_id]
      created_at = session[:pending_passkey_user_created_at]
      return unless user_id && created_at
      return clear_pending_passkey_user if Time.iso8601(created_at) < PASSKEY_CHALLENGE_TTL.ago

      User.find_by(id: user_id)
    rescue ArgumentError
      clear_pending_passkey_user
    end

    def clear_pending_passkey_user
      session.delete(:pending_passkey_user_id)
      session.delete(:pending_passkey_user_created_at)
      nil
    end

    def passkey_challenge_key(kind)
      "passkey_#{kind}_challenge"
    end

    def passkey_challenge_expired?(payload)
      Time.iso8601(payload.fetch("created_at")) < PASSKEY_CHALLENGE_TTL.ago
    rescue ArgumentError, KeyError
      true
    end
end
```

Create `app/services/passkeys/options.rb`:

```ruby
module Passkeys
  class Options
    def self.registration_for(user)
      user.ensure_webauthn_user_id!
      options = WebAuthn::Credential.options_for_create(
        user: {
          id: user.webauthn_user_id,
          name: user.email_address
        },
        exclude: user.passkey_credentials.pluck(:external_id)
      )
      json = JSON.parse(options.to_json)
      json["authenticatorSelection"] = {
        "residentKey" => "required",
        "requireResidentKey" => true,
        "userVerification" => "required"
      }
      json["attestation"] = "none"

      [ options.challenge, json ]
    end

    def self.authentication_for(credentials: [])
      allow = credentials.map { |credential| credential.external_id }
      options = WebAuthn::Credential.options_for_get(allow:)
      json = JSON.parse(options.to_json)
      json["allowCredentials"] = [] if allow.empty?
      json["userVerification"] = "required"

      [ options.challenge, json ]
    end
  end
end
```

Create `app/services/passkeys/registration.rb`:

```ruby
module Passkeys
  class Registration
    def initialize(user:, challenge:, credential_params:, nickname:)
      @user = user
      @challenge = challenge
      @credential_params = credential_params
      @nickname = nickname
    end

    def save!
      webauthn_credential = WebAuthn::Credential.from_create(@credential_params)
      webauthn_credential.verify(@challenge)

      @user.passkey_credentials.create!(
        external_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        sign_count: webauthn_credential.sign_count,
        nickname: @nickname.presence
      )
    end
  end
end
```

Create `app/services/passkeys/assertion.rb`:

```ruby
module Passkeys
  class Assertion
    def initialize(challenge:, credential_params:, user: nil)
      @challenge = challenge
      @credential_params = credential_params
      @user = user
    end

    def verify!
      webauthn_credential = WebAuthn::Credential.from_get(@credential_params)
      credential = find_credential!(webauthn_credential.id)
      webauthn_credential.verify(
        @challenge,
        public_key: credential.public_key,
        sign_count: credential.sign_count
      )
      credential.update!(
        sign_count: webauthn_credential.sign_count,
        last_used_at: Time.current
      )
      credential
    end

    private
      def find_credential!(external_id)
        scope = @user ? @user.passkey_credentials : PasskeyCredential.all
        scope.find_by!(external_id:)
      end
  end
end
```

- [ ] **Step 4: Run service tests**

Run:

```bash
bin/rails test test/services/passkeys/options_test.rb
```

Expected: PASS.

- [ ] **Step 5: Commit service boundaries**

Run:

```bash
git add app/controllers/concerns/passkey_challenges.rb app/services/passkeys test/test_helpers/passkey_test_helper.rb test/test_helper.rb test/services/passkeys/options_test.rb
git commit -m "feat: add passkey ceremony services"
```

Expected: commit succeeds.

## Task 3: Passkey Registration And Profile Management Endpoints

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/passkey_credentials_controller.rb`
- Create: `test/controllers/passkey_credentials_controller_test.rb`

- [ ] **Step 1: Add failing controller tests**

Create `test/controllers/passkey_credentials_controller_test.rb`:

```ruby
require "test_helper"

class PasskeyCredentialsControllerTest < ActionDispatch::IntegrationTest
  test "registration options require current password" do
    sign_in_as(users(:one))

    post options_passkey_credentials_path, params: { current_password: "wrong" }, as: :json

    assert_response :unauthorized
  end

  test "registration options store a challenge after current password confirmation" do
    sign_in_as(users(:one))
    fake = fake_options(payload: { "challenge" => "registration-challenge" })

    WebAuthn::Credential.stub(:options_for_create, fake) do
      post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
    end

    assert_response :success
    assert_equal "registration-challenge", response.parsed_body.fetch("challenge")
  end

  test "creates passkey credential after verified registration" do
    user = users(:one)
    sign_in_as(user)
    fake_options = fake_options(payload: { "challenge" => "registration-challenge" })
    fake_credential = FakeCreatedCredential.new(
      id: "new-passkey-id",
      public_key: "new-public-key",
      sign_count: 4
    )

    WebAuthn::Credential.stub(:options_for_create, fake_options) do
      post options_passkey_credentials_path, params: { current_password: "password" }, as: :json
    end

    assert_difference -> { user.passkey_credentials.count }, 1 do
      WebAuthn::Credential.stub(:from_create, fake_credential) do
        post passkey_credentials_path, params: {
          nickname: "Phone",
          credential: { id: "new-passkey-id" }
        }, as: :json
      end
    end

    assert_response :created
    credential = user.passkey_credentials.order(:created_at).last
    assert_equal "new-passkey-id", credential.external_id
    assert_equal "new-public-key", credential.public_key
    assert_equal 4, credential.sign_count
    assert_equal "Phone", credential.nickname
  end

  test "renames own passkey" do
    sign_in_as(users(:one))
    credential = passkey_credentials(:one_touch_id)

    patch passkey_credential_path(credential), params: { passkey_credential: { nickname: "YubiKey" } }

    assert_redirected_to edit_profile_path
    assert_equal "YubiKey", credential.reload.nickname
  end

  test "does not rename another user's passkey" do
    sign_in_as(users(:two))
    credential = passkey_credentials(:one_touch_id)

    patch passkey_credential_path(credential), params: { passkey_credential: { nickname: "Stolen" } }

    assert_redirected_to edit_profile_path
    assert_equal "MacBook Touch ID", credential.reload.nickname
  end

  test "enabling second factor requires a passkey and current password" do
    user = users(:two)
    sign_in_as(user)

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "1",
        current_password: "password"
      }
    }

    assert_response :unprocessable_entity
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "enabling and disabling second factor requires current password" do
    user = users(:one)
    sign_in_as(user)

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "1",
        current_password: "password"
      }
    }

    assert_redirected_to edit_profile_path
    assert user.reload.passkey_second_factor_enabled?

    patch second_factor_passkey_credentials_path, params: {
      user: {
        passkey_second_factor_enabled: "0",
        current_password: "password"
      }
    }

    assert_redirected_to edit_profile_path
    assert_not user.reload.passkey_second_factor_enabled?
  end

  test "deleting last passkey disables second factor with current password" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    sign_in_as(user)
    credential = passkey_credentials(:one_touch_id)

    assert_difference -> { user.passkey_credentials.count }, -1 do
      delete passkey_credential_path(credential), params: { current_password: "password" }
    end

    assert_redirected_to edit_profile_path
    assert_not user.reload.passkey_second_factor_enabled?
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/passkey_credentials_controller_test.rb
```

Expected: FAIL with missing route helpers.

- [ ] **Step 3: Add routes**

Insert these routes after `resource :password_change` in `config/routes.rb`:

```ruby
  resources :passkey_credentials, only: %i[create update destroy] do
    post :options, on: :collection
    patch :second_factor, on: :collection
  end
```

- [ ] **Step 4: Implement controller**

Create `app/controllers/passkey_credentials_controller.rb`:

```ruby
class PasskeyCredentialsController < ApplicationController
  include PasskeyChallenges

  def options
    unless Current.user.authenticate(params[:current_password].to_s)
      return render json: { error: t(".current_password_invalid") }, status: :unauthorized
    end

    challenge, options = Passkeys::Options.registration_for(Current.user)
    store_passkey_challenge(:registration, challenge, user_id: Current.user.id)
    render json: options
  end

  def create
    challenge = consume_passkey_challenge(:registration, user_id: Current.user.id)
    return render json: { error: t(".failed") }, status: :unprocessable_entity unless challenge

    credential = Passkeys::Registration.new(
      user: Current.user,
      challenge:,
      credential_params: credential_params,
      nickname: params[:nickname]
    ).save!
    render json: { redirect_url: edit_profile_path, id: credential.id }, status: :created
  rescue WebAuthn::Error, ActiveRecord::RecordInvalid
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end

  def update
    credential = Current.user.passkey_credentials.find_by(id: params[:id])
    return redirect_to edit_profile_path, alert: t(".not_found") unless credential

    credential.update!(passkey_credential_params)
    redirect_to edit_profile_path, notice: t(".renamed")
  end

  def destroy
    credential = Current.user.passkey_credentials.find_by(id: params[:id])
    return redirect_to edit_profile_path, alert: t(".not_found") unless credential

    if Current.user.passkey_credentials.one?
      unless Current.user.authenticate(params[:current_password].to_s)
        return redirect_to edit_profile_path, alert: t(".current_password_invalid")
      end

      Current.user.update!(passkey_second_factor_enabled: false)
    end

    credential.destroy!
    redirect_to edit_profile_path, notice: t(".deleted")
  end

  def second_factor
    unless Current.user.authenticate(second_factor_params[:current_password].to_s)
      Current.user.errors.add(:base, t(".current_password_invalid"))
      @user = Current.user
      return render "profiles/edit", status: :unprocessable_entity
    end

    Current.user.update!(passkey_second_factor_enabled: second_factor_params[:passkey_second_factor_enabled] == "1")
    redirect_to edit_profile_path, notice: t(".updated")
  rescue ActiveRecord::RecordInvalid
    @user = Current.user
    render "profiles/edit", status: :unprocessable_entity
  end

  private
    def credential_params
      params.require(:credential).permit!.to_h
    end

    def passkey_credential_params
      params.require(:passkey_credential).permit(:nickname)
    end

    def second_factor_params
      params.require(:user).permit(:passkey_second_factor_enabled, :current_password)
    end
end
```

- [ ] **Step 5: Add translations**

Add this block under the top-level `en:` key in `config/locales/en.yml`:

```yaml
  passkey_credentials:
    create:
      failed: "Passkey could not be added."
    destroy:
      current_password_invalid: "Current password is not correct."
      deleted: "Passkey deleted."
      not_found: "Passkey not found."
    options:
      current_password_invalid: "Current password is not correct."
    second_factor:
      current_password_invalid: "Current password is not correct."
      updated: "Passkey security updated."
    update:
      not_found: "Passkey not found."
      renamed: "Passkey renamed."
```

- [ ] **Step 6: Run registration endpoint tests**

Run:

```bash
bin/rails test test/controllers/passkey_credentials_controller_test.rb
```

Expected: PASS.

- [ ] **Step 7: Commit registration endpoints**

Run:

```bash
git add config/routes.rb app/controllers/passkey_credentials_controller.rb config/locales/en.yml test/controllers/passkey_credentials_controller_test.rb
git commit -m "feat: add passkey registration endpoints"
```

Expected: commit succeeds.

## Task 4: Browser-Picker Passkey Login

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/passkey_sessions_controller.rb`
- Create: `test/controllers/passkey_sessions_controller_test.rb`

- [ ] **Step 1: Add failing passkey login tests**

Create `test/controllers/passkey_sessions_controller_test.rb`:

```ruby
require "test_helper"

class PasskeySessionsControllerTest < ActionDispatch::IntegrationTest
  test "login options use browser account picker" do
    fake = fake_options(payload: { "challenge" => "login-challenge" })

    WebAuthn::Credential.stub(:options_for_get, fake) do
      post options_passkey_session_path, as: :json
    end

    assert_response :success
    assert_equal [], response.parsed_body.fetch("allowCredentials")
    assert_equal "required", response.parsed_body.fetch("userVerification")
  end

  test "verified passkey starts a session" do
    credential = passkey_credentials(:one_touch_id)
    fake_options = fake_options(payload: { "challenge" => "login-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: credential.external_id, sign_count: 3)

    WebAuthn::Credential.stub(:options_for_get, fake_options) do
      post options_passkey_session_path, as: :json
    end

    assert_difference -> { credential.user.sessions.count }, 1 do
      WebAuthn::Credential.stub(:from_get, fake_assertion) do
        post passkey_session_path, params: { credential: { id: credential.external_id } }, as: :json
      end
    end

    assert_response :success
    assert cookies[:session_id].present?
    assert_equal root_path, response.parsed_body.fetch("redirect_url")
    assert_equal 3, credential.reload.sign_count
    assert credential.last_used_at.present?
  end

  test "unknown credential fails generically" do
    fake_options = fake_options(payload: { "challenge" => "login-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: "unknown-credential", sign_count: 3)

    WebAuthn::Credential.stub(:options_for_get, fake_options) do
      post options_passkey_session_path, as: :json
    end

    WebAuthn::Credential.stub(:from_get, fake_assertion) do
      post passkey_session_path, params: { credential: { id: "unknown-credential" } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
    assert_equal "Passkey sign-in failed.", response.parsed_body.fetch("error")
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/passkey_sessions_controller_test.rb
```

Expected: FAIL with missing route helpers.

- [ ] **Step 3: Add routes**

Insert this route block after `resource :session` in `config/routes.rb`:

```ruby
  resource :passkey_session, only: :create, path: "session/passkey" do
    post :options
  end
```

- [ ] **Step 4: Implement controller**

Create `app/controllers/passkey_sessions_controller.rb`:

```ruby
class PasskeySessionsController < ApplicationController
  include PasskeyChallenges

  allow_unauthenticated_access only: %i[options create]
  rate_limit to: 10, within: 3.minutes, only: %i[options create], with: -> { render json: { error: t(".rate_limited") }, status: :too_many_requests }

  def options
    challenge, options = Passkeys::Options.authentication_for
    store_passkey_challenge(:login, challenge)
    render json: options
  end

  def create
    challenge = consume_passkey_challenge(:login)
    return render json: { error: t(".failed") }, status: :unprocessable_entity unless challenge

    credential = Passkeys::Assertion.new(
      challenge:,
      credential_params: credential_params
    ).verify!

    start_new_session_for(credential.user)
    render json: { redirect_url: after_authentication_url }
  rescue ActiveRecord::RecordNotFound, WebAuthn::Error
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end

  private
    def credential_params
      params.require(:credential).permit!.to_h
    end
end
```

Add translations:

```yaml
  passkey_sessions:
    create:
      failed: "Passkey sign-in failed."
    options:
      rate_limited: "Try again later."
```

- [ ] **Step 5: Run passkey login tests**

Run:

```bash
bin/rails test test/controllers/passkey_sessions_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit browser-picker login**

Run:

```bash
git add config/routes.rb app/controllers/passkey_sessions_controller.rb config/locales/en.yml test/controllers/passkey_sessions_controller_test.rb
git commit -m "feat: add browser passkey login"
```

Expected: commit succeeds.

## Task 5: Password Login With Optional Passkey Second Factor

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/sessions_controller.rb`
- Create: `app/controllers/passkey_second_factors_controller.rb`
- Create: `app/views/passkey_second_factors/show.html.erb`
- Modify: `test/controllers/sessions_controller_test.rb`
- Create: `test/controllers/passkey_second_factors_controller_test.rb`

- [ ] **Step 1: Add failing tests**

Append this test to `test/controllers/sessions_controller_test.rb`:

```ruby
  test "create with valid credentials and passkey second factor redirects without creating session" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)

    assert_no_difference -> { user.sessions.count } do
      post session_path, params: { email_address: user.email_address, password: "password" }
    end

    assert_redirected_to passkey_second_factor_path
    assert_nil cookies[:session_id]
  end
```

Create `test/controllers/passkey_second_factors_controller_test.rb`:

```ruby
require "test_helper"

class PasskeySecondFactorsControllerTest < ActionDispatch::IntegrationTest
  test "show redirects without pending password login" do
    get passkey_second_factor_path

    assert_redirected_to new_session_path
  end

  test "options are scoped to pending user's credentials" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    fake = fake_options(payload: { "challenge" => "second-factor-challenge" })

    post session_path, params: { email_address: user.email_address, password: "password" }

    WebAuthn::Credential.stub(:options_for_get, fake) do
      post options_passkey_second_factor_path, as: :json
    end

    assert_response :success
    assert_equal "required", response.parsed_body.fetch("userVerification")
  end

  test "verified second factor starts session and clears pending state" do
    credential = passkey_credentials(:one_touch_id)
    user = credential.user
    user.update!(passkey_second_factor_enabled: true)
    fake_options = fake_options(payload: { "challenge" => "second-factor-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: credential.external_id, sign_count: 8)

    post session_path, params: { email_address: user.email_address, password: "password" }

    WebAuthn::Credential.stub(:options_for_get, fake_options) do
      post options_passkey_second_factor_path, as: :json
    end

    assert_difference -> { user.sessions.count }, 1 do
      WebAuthn::Credential.stub(:from_get, fake_assertion) do
        post passkey_second_factor_path, params: { credential: { id: credential.external_id } }, as: :json
      end
    end

    assert_response :success
    assert cookies[:session_id].present?
    assert_equal root_path, response.parsed_body.fetch("redirect_url")
  end

  test "pending second factor expires after ten minutes" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)

    post session_path, params: { email_address: user.email_address, password: "password" }

    travel 11.minutes do
      post options_passkey_second_factor_path, as: :json
    end

    assert_response :unauthorized
    assert_nil cookies[:session_id]
  end

  test "credential for a different user fails second factor" do
    pending_user = users(:two)
    pending_user.passkey_credentials.create!(
      external_id: "credential-two",
      public_key: "public-key-two",
      sign_count: 0
    )
    pending_user.update!(passkey_second_factor_enabled: true)
    other_credential = passkey_credentials(:one_touch_id)
    fake_options = fake_options(payload: { "challenge" => "second-factor-challenge" })
    fake_assertion = FakeAssertedCredential.new(id: other_credential.external_id, sign_count: 8)

    post session_path, params: { email_address: pending_user.email_address, password: "password" }

    WebAuthn::Credential.stub(:options_for_get, fake_options) do
      post options_passkey_second_factor_path, as: :json
    end

    WebAuthn::Credential.stub(:from_get, fake_assertion) do
      post passkey_second_factor_path, params: { credential: { id: other_credential.external_id } }, as: :json
    end

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
bin/rails test test/controllers/sessions_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb
```

Expected: FAIL with missing `passkey_second_factor_path`.

- [ ] **Step 3: Add route and session branching**

Insert this route block after `resource :passkey_session` in `config/routes.rb`:

```ruby
  resource :passkey_second_factor, only: %i[show create], path: "session/passkey_second_factor" do
    post :options
  end
```

Modify `app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  include PasskeyChallenges

  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.passkey_second_factor_enabled?
        store_pending_passkey_user(user)
        redirect_to passkey_second_factor_path
      else
        start_new_session_for user
        redirect_to after_authentication_url
      end
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    clear_pending_passkey_user
    redirect_to new_session_path, status: :see_other
  end
end
```

- [ ] **Step 4: Implement second-factor controller and view**

Create `app/controllers/passkey_second_factors_controller.rb`:

```ruby
class PasskeySecondFactorsController < ApplicationController
  include PasskeyChallenges

  allow_unauthenticated_access only: %i[show options create]
  rate_limit to: 10, within: 3.minutes, only: %i[options create], with: -> { render json: { error: t(".rate_limited") }, status: :too_many_requests }

  def show
    redirect_to new_session_path, alert: t(".expired") unless pending_passkey_user
  end

  def options
    user = pending_passkey_user
    return render json: { error: t(".expired") }, status: :unauthorized unless user

    challenge, options = Passkeys::Options.authentication_for(credentials: user.passkey_credentials)
    store_passkey_challenge(:second_factor, challenge, user_id: user.id)
    render json: options
  end

  def create
    user = pending_passkey_user
    return render json: { error: t(".expired") }, status: :unauthorized unless user

    challenge = consume_passkey_challenge(:second_factor, user_id: user.id)
    return render json: { error: t(".failed") }, status: :unprocessable_entity unless challenge

    Passkeys::Assertion.new(
      challenge:,
      credential_params: credential_params,
      user:
    ).verify!

    clear_pending_passkey_user
    start_new_session_for(user)
    render json: { redirect_url: after_authentication_url }
  rescue ActiveRecord::RecordNotFound, WebAuthn::Error
    clear_pending_passkey_user
    render json: { error: t(".failed") }, status: :unprocessable_entity
  end

  private
    def credential_params
      params.require(:credential).permit!.to_h
    end
end
```

Create `app/views/passkey_second_factors/show.html.erb`:

```erb
<main class="min-h-screen bg-stone-50">
  <section class="mx-auto max-w-md px-6 py-10">
    <%= link_to root_path, class: "mb-6 inline-block" do %>
      <%= render "shared/brand_wordmark",
        container_class: "block h-14 w-64",
        image_class: "h-full w-full object-contain object-left" %>
    <% end %>

    <% if alert = flash[:alert] %>
      <p class="mb-5 inline-block rounded-lg bg-red-50 px-3 py-2 font-medium text-red-500" id="alert"><%= alert %></p>
    <% end %>

    <div class="rounded-lg border border-stone-200 bg-white p-6 shadow-sm">
      <h1 class="text-3xl font-bold text-stone-950"><%= t(".title") %></h1>
      <p class="mt-3 text-sm text-stone-600"><%= t(".intro") %></p>

      <div
        class="mt-6"
        data-controller="passkey"
        data-passkey-options-url-value="<%= options_passkey_second_factor_path %>"
        data-passkey-submit-url-value="<%= passkey_second_factor_path %>">
        <button type="button" data-action="passkey#authenticate" class="w-full rounded-md bg-stone-950 px-5 py-3 text-sm font-semibold text-white shadow-sm hover:bg-stone-800">
          <%= t(".verify") %>
        </button>
        <p class="mt-3 hidden text-sm text-red-600" data-passkey-target="error"></p>
      </div>
    </div>
  </section>
</main>
```

Add translations:

```yaml
  passkey_second_factors:
    create:
      expired: "Passkey verification expired. Sign in again."
      failed: "Passkey verification failed."
    options:
      expired: "Passkey verification expired. Sign in again."
      rate_limited: "Try again later."
    show:
      expired: "Passkey verification expired. Sign in again."
      intro: "Use one of your passkeys to finish signing in."
      title: "Verify passkey"
      verify: "Verify with passkey"
```

- [ ] **Step 5: Run second-factor tests**

Run:

```bash
bin/rails test test/controllers/sessions_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb
```

Expected: PASS.

- [ ] **Step 6: Commit second-factor flow**

Run:

```bash
git add config/routes.rb app/controllers/sessions_controller.rb app/controllers/passkey_second_factors_controller.rb app/views/passkey_second_factors/show.html.erb config/locales/en.yml test/controllers/sessions_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb
git commit -m "feat: require passkey after password login"
```

Expected: commit succeeds.

## Task 6: Stimulus Passkey UI

**Files:**
- Create: `app/javascript/controllers/passkey_controller.js`
- Modify: `app/views/sessions/new.html.erb`
- Modify: `app/views/profiles/edit.html.erb`
- Create: `app/views/profiles/_passkeys.html.erb`
- Modify: `config/locales/en.yml`
- Modify: `test/controllers/profiles_controller_test.rb`

- [ ] **Step 1: Add failing Profile UI test**

Append this test to `test/controllers/profiles_controller_test.rb`:

```ruby
  test "profile shows passkey account security controls" do
    sign_in_as(users(:one))

    get edit_profile_path

    assert_response :success
    assert_select "h2", I18n.t("profiles.passkeys.title")
    assert_select "[data-controller=?]", "passkey"
    assert_select "form[action=?]", second_factor_passkey_credentials_path
    assert_select "form[action=?]", passkey_credential_path(passkey_credentials(:one_touch_id))
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/profiles_controller_test.rb
```

Expected: FAIL because passkey controls are not rendered.

- [ ] **Step 3: Add Stimulus controller**

Create `app/javascript/controllers/passkey_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["error", "currentPassword", "nickname"]
  static values = {
    optionsUrl: String,
    submitUrl: String
  }

  async register(event) {
    event.preventDefault()
    this.clearError()

    try {
      const options = await this.fetchOptions({
        current_password: this.currentPasswordTarget.value
      })
      const credential = await navigator.credentials.create({
        publicKey: this.decodePublicKeyOptions(options)
      })
      const response = await this.submitCredential({
        nickname: this.hasNicknameTarget ? this.nicknameTarget.value : "",
        credential: this.encodeRegistrationCredential(credential)
      })
      window.location.href = response.redirect_url
    } catch (error) {
      this.showError(error)
    }
  }

  async authenticate(event) {
    event.preventDefault()
    this.clearError()

    try {
      const options = await this.fetchOptions({})
      const credential = await navigator.credentials.get({
        publicKey: this.decodePublicKeyOptions(options)
      })
      const response = await this.submitCredential({
        credential: this.encodeAssertionCredential(credential)
      })
      window.location.href = response.redirect_url
    } catch (error) {
      this.showError(error)
    }
  }

  async fetchOptions(body) {
    const response = await fetch(this.optionsUrlValue, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(body)
    })
    const payload = await response.json()
    if (!response.ok) throw new Error(payload.error || "Passkey request failed.")
    return payload
  }

  async submitCredential(body) {
    const response = await fetch(this.submitUrlValue, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify(body)
    })
    const payload = await response.json()
    if (!response.ok) throw new Error(payload.error || "Passkey verification failed.")
    return payload
  }

  headers() {
    return {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
    }
  }

  decodePublicKeyOptions(publicKey) {
    const decoded = { ...publicKey }
    decoded.challenge = this.base64urlToBuffer(publicKey.challenge)

    if (decoded.user && decoded.user.id) {
      decoded.user = { ...decoded.user, id: this.base64urlToBuffer(decoded.user.id) }
    }

    if (decoded.allowCredentials) {
      decoded.allowCredentials = decoded.allowCredentials.map((credential) => ({
        ...credential,
        id: this.base64urlToBuffer(credential.id)
      }))
    }

    if (decoded.excludeCredentials) {
      decoded.excludeCredentials = decoded.excludeCredentials.map((credential) => ({
        ...credential,
        id: this.base64urlToBuffer(credential.id)
      }))
    }

    return decoded
  }

  encodeRegistrationCredential(credential) {
    return {
      id: credential.id,
      rawId: this.bufferToBase64url(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
        attestationObject: this.bufferToBase64url(credential.response.attestationObject)
      },
      clientExtensionResults: credential.getClientExtensionResults()
    }
  }

  encodeAssertionCredential(credential) {
    return {
      id: credential.id,
      rawId: this.bufferToBase64url(credential.rawId),
      type: credential.type,
      response: {
        clientDataJSON: this.bufferToBase64url(credential.response.clientDataJSON),
        authenticatorData: this.bufferToBase64url(credential.response.authenticatorData),
        signature: this.bufferToBase64url(credential.response.signature),
        userHandle: credential.response.userHandle ? this.bufferToBase64url(credential.response.userHandle) : null
      },
      clientExtensionResults: credential.getClientExtensionResults()
    }
  }

  base64urlToBuffer(value) {
    const padding = "=".repeat((4 - value.length % 4) % 4)
    const base64 = (value + padding).replace(/-/g, "+").replace(/_/g, "/")
    const binary = window.atob(base64)
    const bytes = new Uint8Array(binary.length)
    for (let index = 0; index < binary.length; index++) bytes[index] = binary.charCodeAt(index)
    return bytes.buffer
  }

  bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    bytes.forEach((byte) => { binary += String.fromCharCode(byte) })
    return window.btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }

  showError(error) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = error.message
    this.errorTarget.classList.remove("hidden")
  }
}
```

- [ ] **Step 4: Add sign-in passkey button**

Insert this block in `app/views/sessions/new.html.erb` below the `<h1>` and before the password form:

```erb
  <div
    class="my-5"
    data-controller="passkey"
    data-passkey-options-url-value="<%= options_passkey_session_path %>"
    data-passkey-submit-url-value="<%= passkey_session_path %>">
    <button type="button" data-action="passkey#authenticate" class="w-full rounded-md border border-stone-300 px-3.5 py-2.5 text-center font-medium text-stone-900 hover:bg-stone-100">
      <%= t(".sign_in_with_passkey") %>
    </button>
    <p class="mt-2 hidden text-sm text-red-600" data-passkey-target="error"></p>
  </div>
```

- [ ] **Step 5: Add Profile partial and render it**

Insert this line in `app/views/profiles/edit.html.erb` after the profile form's closing `<% end %>` and before the surrounding card `</div>` so passkey forms are not nested inside the profile form:

```erb
        <%= render "passkeys", user: @user %>
```

Create `app/views/profiles/_passkeys.html.erb`:

```erb
<section class="rounded-md border border-stone-200 bg-stone-50 p-4">
  <h2 class="text-lg font-semibold text-stone-950"><%= t("profiles.passkeys.title") %></h2>
  <p class="mt-1 text-sm text-stone-600"><%= t("profiles.passkeys.intro") %></p>

  <div
    class="mt-4 space-y-3"
    data-controller="passkey"
    data-passkey-options-url-value="<%= options_passkey_credentials_path %>"
    data-passkey-submit-url-value="<%= passkey_credentials_path %>">
    <div>
      <label class="block text-sm font-medium text-stone-700" for="passkey_current_password"><%= t("profiles.passkeys.current_password") %></label>
      <input id="passkey_current_password" type="password" autocomplete="current-password" data-passkey-target="currentPassword" class="mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none">
    </div>
    <div>
      <label class="block text-sm font-medium text-stone-700" for="passkey_nickname"><%= t("profiles.passkeys.nickname") %></label>
      <input id="passkey_nickname" type="text" data-passkey-target="nickname" class="mt-1 w-full rounded-md border border-stone-300 px-3 py-2 text-stone-950 shadow-sm focus:border-stone-900 focus:outline-none">
    </div>
    <button type="button" data-action="passkey#register" class="rounded-md bg-stone-950 px-4 py-2 text-sm font-semibold text-white hover:bg-stone-800"><%= t("profiles.passkeys.add") %></button>
    <p class="hidden text-sm text-red-600" data-passkey-target="error"></p>
  </div>

  <div class="mt-5 space-y-3">
    <% user.passkey_credentials.order(:created_at).each do |credential| %>
      <div class="rounded-md border border-stone-200 bg-white p-3">
        <p class="font-medium text-stone-950"><%= credential.display_name %></p>
        <p class="mt-1 text-xs text-stone-500">
          <%= t("profiles.passkeys.added", date: l(credential.created_at.to_date)) %>
          <% if credential.last_used_at %>
            <span><%= t("profiles.passkeys.last_used", time: l(credential.last_used_at, format: :short)) %></span>
          <% end %>
        </p>

        <%= form_with model: credential, url: passkey_credential_path(credential), method: :patch, class: "mt-3 flex gap-2" do |form| %>
          <%= form.text_field :nickname, placeholder: t("profiles.passkeys.nickname"), class: "min-w-0 flex-1 rounded-md border border-stone-300 px-3 py-2 text-sm text-stone-950" %>
          <%= form.submit t("profiles.passkeys.rename"), class: "rounded-md border border-stone-300 px-3 py-2 text-sm font-semibold text-stone-800 hover:bg-stone-100" %>
        <% end %>

        <%= form_with url: passkey_credential_path(credential), method: :delete, class: "mt-3 space-y-2" do |form| %>
          <% if user.passkey_credentials.one? %>
            <%= form.password_field :current_password, autocomplete: "current-password", placeholder: t("profiles.passkeys.current_password"), class: "w-full rounded-md border border-stone-300 px-3 py-2 text-sm text-stone-950" %>
          <% end %>
          <%= form.submit t("profiles.passkeys.delete"), class: "rounded-md border border-red-200 px-3 py-2 text-sm font-semibold text-red-700 hover:bg-red-50" %>
        <% end %>
      </div>
    <% end %>
  </div>

  <%= form_with url: second_factor_passkey_credentials_path, method: :patch, scope: :user, class: "mt-5 space-y-3" do |form| %>
    <label class="flex items-center gap-2 text-sm font-medium text-stone-800">
      <%= form.check_box :passkey_second_factor_enabled, checked: user.passkey_second_factor_enabled?, disabled: user.passkey_credentials.none?, class: "rounded border-stone-300 text-stone-950" %>
      <span><%= t("profiles.passkeys.require_after_password") %></span>
    </label>
    <%= form.password_field :current_password, autocomplete: "current-password", placeholder: t("profiles.passkeys.current_password"), class: "w-full rounded-md border border-stone-300 px-3 py-2 text-sm text-stone-950" %>
    <%= form.submit t("profiles.passkeys.save_second_factor"), class: "rounded-md border border-stone-300 px-3 py-2 text-sm font-semibold text-stone-800 hover:bg-stone-100" %>
  <% end %>
</section>
```

- [ ] **Step 6: Add UI translations**

Add this key under the existing `sessions.new` block:

```yaml
      sign_in_with_passkey: "Sign in with passkey"
```

Add this `profiles.passkeys` block alongside the existing `profiles.edit` and `profiles.update` blocks:

```yaml
  profiles:
    passkeys:
      add: "Add passkey"
      added: "Added %{date}"
      current_password: "Current password"
      delete: "Delete passkey"
      intro: "Passkeys let this browser or device sign you in after local verification."
      last_used: "Last used %{time}"
      nickname: "Passkey name"
      rename: "Rename"
      require_after_password: "Require passkey after password sign-in"
      save_second_factor: "Save passkey security"
      title: "Passkeys"
```

- [ ] **Step 7: Run UI test and lint relevant JS**

Run:

```bash
bin/rails test test/controllers/profiles_controller_test.rb
```

Expected: PASS.

Run:

```bash
bin/rails test test/controllers/passkey_credentials_controller_test.rb test/controllers/passkey_sessions_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb
```

Expected: PASS.

- [ ] **Step 8: Commit UI**

Run:

```bash
git add app/javascript/controllers/passkey_controller.js app/views/sessions/new.html.erb app/views/profiles/edit.html.erb app/views/profiles/_passkeys.html.erb config/locales/en.yml test/controllers/profiles_controller_test.rb
git commit -m "feat: add passkey account UI"
```

Expected: commit succeeds.

## Task 7: Password-Reset Recovery, Documentation, And Full Verification

**Files:**
- Modify: `app/controllers/passwords_controller.rb`
- Modify: `test/controllers/passwords_controller_test.rb`
- Modify: `docs/account-privacy.md`
- Modify: `docs/setup.md`
- Modify: `docs/production-self-hosting.md`
- Modify: `docs/status.md`

- [ ] **Step 1: Add failing password reset recovery test**

Append this test to `test/controllers/passwords_controller_test.rb`:

```ruby
  test "password reset disables passkey second factor and preserves passkeys" do
    user = users(:one)
    user.update!(passkey_second_factor_enabled: true)
    passkey_count = user.passkey_credentials.count

    put password_path(user.password_reset_token), params: {
      password: "new-password",
      password_confirmation: "new-password"
    }

    assert_redirected_to new_session_path
    assert_not user.reload.passkey_second_factor_enabled?
    assert_equal passkey_count, user.passkey_credentials.count
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
bin/rails test test/controllers/passwords_controller_test.rb
```

Expected: FAIL because `passkey_second_factor_enabled` remains true.

- [ ] **Step 3: Implement recovery behavior**

Modify `app/controllers/passwords_controller.rb` in `update` so successful password reset disables passkey second factor before destroying sessions:

```ruby
  def update
    if @user.update(params.permit(:password, :password_confirmation).merge(passkey_second_factor_enabled: false))
      @user.sessions.destroy_all
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end
```

- [ ] **Step 4: Run password reset tests**

Run:

```bash
bin/rails test test/controllers/passwords_controller_test.rb
```

Expected: PASS.

- [ ] **Step 5: Update docs**

Append this paragraph to `docs/account-privacy.md` under `## Email Placement`:

```markdown

## Passkeys

Passkey controls belong in Profile because they are account-security UI. They may show the signed-in user's email address as account context, but coffee/product pages should continue to use `User#display_label`.
```

Add this subsection to `docs/setup.md` near the local server instructions:

```markdown

### Local Passkey Origin

Passkey development defaults to `http://localhost:3001`, matching the preferred local Rails port. If you use a different local hostname or port, set `ROASTNODE_WEBAUTHN_ORIGIN` before starting Rails.
```

Add this subsection to `docs/production-self-hosting.md` near environment/secrets configuration:

```markdown

### Passkey Origin

Set `ROASTNODE_WEBAUTHN_ORIGIN` to the public HTTPS origin users open in their browser, for example `https://coffee.example.com`. Set `ROASTNODE_WEBAUTHN_RP_ID` only when you intentionally want credentials scoped to a parent domain such as `example.com`.

Passkeys are bound to the WebAuthn origin/RP ID. Changing the public hostname or RP ID can make existing passkeys unusable, so treat these values as stable production identity settings.
```

Update the authentication bullet in `docs/status.md` from:

```markdown
- Rails-native authentication, first-user setup for empty installs, password reset and signed-in password change flows, private-by-default app shell, and an instance admin dashboard with safe read-only checks plus backup controls.
```

to:

```markdown
- Rails-native authentication, first-user setup for empty installs, password reset, signed-in password change flows, optional user passkeys with browser-picker login and passkey second factor, private-by-default app shell, and an instance admin dashboard with safe read-only checks plus backup controls.
```

- [ ] **Step 6: Run focused passkey and auth tests**

Run:

```bash
bin/rails test test/models/passkey_credential_test.rb test/models/user_test.rb test/controllers/passkey_credentials_controller_test.rb test/controllers/passkey_sessions_controller_test.rb test/controllers/passkey_second_factors_controller_test.rb test/controllers/sessions_controller_test.rb test/controllers/passwords_controller_test.rb test/controllers/profiles_controller_test.rb
```

Expected: PASS.

- [ ] **Step 7: Run full verification**

Run:

```bash
bin/rails test
bin/brakeman
```

Expected: both commands complete successfully. If `bin/brakeman` reports a new warning, fix it before continuing.

- [ ] **Step 8: Start local server for user-facing verification**

Run:

```bash
bin/rails server -p 3001 -b 0.0.0.0
```

Expected: server starts on port `3001`. Open `http://localhost:3001/session` in the in-app browser and verify the sign-in page renders the password form plus the passkey button. Open Profile after signing in and verify the Passkeys section renders without overlapping controls.

- [ ] **Step 9: Commit recovery and docs**

Run:

```bash
git add app/controllers/passwords_controller.rb test/controllers/passwords_controller_test.rb docs/account-privacy.md docs/setup.md docs/production-self-hosting.md docs/status.md
git commit -m "feat: add passkey recovery documentation"
```

Expected: commit succeeds.
