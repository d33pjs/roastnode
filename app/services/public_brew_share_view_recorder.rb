class PublicBrewShareViewRecorder
  USER_AGENT_LIMIT = 512

  def initialize(share:, request:)
    @share = share
    @request = request
  end

  def call
    PublicBrewShareView.create!(
      public_brew_share: share,
      ip_address: request.remote_ip,
      user_agent: request.user_agent.to_s.first(USER_AGENT_LIMIT),
      viewed_at: Time.current
    )
  end

  private
    attr_reader :share, :request
end
