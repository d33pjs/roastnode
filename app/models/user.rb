class User < ApplicationRecord
  UNKNOWN_DISPLAY_LABEL = "unknown username"
  DEFAULT_LANDING_SCREENS = %w[dashboard log_espresso].freeze
  THEMES = %w[light dark].freeze
  NUMBER_FORMATS = %w[comma_decimal dot_decimal].freeze
  TIME_FORMATS = %w[european_24h_seconds us_12h_seconds].freeze
  DEFAULT_BREW_FOCUS_FIELDS = %w[
    bean_weight_grams
    ground_weight_grams
    dose_grams
    beverage_grams
    grind_setting
    brew_temperature_celsius
    total_time_seconds
    preinfusion_seconds
    first_drip_seconds
    notes
  ].freeze
  HIDEABLE_BREW_FIELDS = %w[
    ground_weight_grams
    dose_grams
    beverage_grams
    grind_setting
    brew_temperature_celsius
    total_time_seconds
    preinfusion_seconds
    first_drip_seconds
    taste_balance
    rating
    channeling
    notes
    photos
  ].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :passkey_credentials, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :workspaces, through: :memberships
  has_many :created_workspace_invites, class_name: "WorkspaceInvite", foreign_key: :created_by_id, dependent: :destroy,
    inverse_of: :created_by
  has_many :accepted_workspace_invites, class_name: "WorkspaceInvite", foreign_key: :accepted_by_id, dependent: :nullify,
    inverse_of: :accepted_by
  has_many :data_imports, dependent: :restrict_with_exception
  has_many :brews, dependent: :restrict_with_exception
  has_many :inventory_adjustments, dependent: :restrict_with_exception
  has_many :equipment_events, dependent: :restrict_with_exception
  has_one_attached :avatar
  has_one_attached :public_banner

  belongs_to :active_workspace, class_name: "Workspace", optional: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :display_name, with: ->(name) { name.strip.presence }

  validates :email_address, presence: true, uniqueness: { case_sensitive: false }
  validates :display_name, length: { maximum: 80 }
  validates :default_landing_screen, inclusion: { in: DEFAULT_LANDING_SCREENS }
  validates :theme, inclusion: { in: THEMES }
  validates :number_format, inclusion: { in: NUMBER_FORMATS }
  validates :time_format, inclusion: { in: TIME_FORMATS }
  validates :default_brew_focus_field, inclusion: { in: DEFAULT_BREW_FOCUS_FIELDS }
  validate :hidden_brew_field_names_supported
  validate :passkey_second_factor_requires_passkey

  def default_landing_log_espresso?
    default_landing_screen == "log_espresso"
  end

  def dark_theme?
    theme == "dark"
  end

  def membership_for(workspace)
    memberships.find_by(workspace:)
  end

  def display_label
    display_name.presence || UNKNOWN_DISPLAY_LABEL
  end

  def hidden_brew_field_names
    Array(self[:hidden_brew_field_names])
  end

  def hidden_brew_field_names=(values)
    self[:hidden_brew_field_names] = Array(values).compact_blank.uniq & HIDEABLE_BREW_FIELDS
  end

  def ensure_active_workspace!
    return active_workspace if active_workspace.present? && memberships.exists?(workspace: active_workspace)

    workspace = workspaces.first
    return unless workspace

    update_column(:active_workspace_id, workspace.id)
    self.active_workspace = workspace
  end

  def ensure_webauthn_user_id!
    return webauthn_user_id if webauthn_user_id.present?

    update!(webauthn_user_id: WebAuthn.generate_user_id)
    webauthn_user_id
  end

  private
    def hidden_brew_field_names_supported
      unsupported_fields = hidden_brew_field_names - HIDEABLE_BREW_FIELDS
      return if unsupported_fields.empty?

      errors.add(:hidden_brew_field_names, "contains unsupported fields")
    end

    def passkey_second_factor_requires_passkey
      return unless passkey_second_factor_enabled?
      return if passkey_credentials.exists?

      errors.add(:passkey_second_factor_enabled, "requires at least one passkey")
    end
end
