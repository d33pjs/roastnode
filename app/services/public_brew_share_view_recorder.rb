class PublicBrewShareViewRecorder
  IP_ADDRESS_LIMIT = 255
  USER_AGENT_LIMIT = 512

  def initialize(share:, request:)
    @share = share
    @request = request
  end

  def call
    PublicBrewShareView.create!(
      public_brew_share: share,
      ip_address: ip_address,
      user_agent: user_agent,
      viewed_at: Time.current
    )
  rescue StandardError => error
    Rails.logger.info(
      "PublicBrewShareViewRecorder failed " \
        "exception_class=#{error.class.name} " \
        "public_brew_share_id=#{share.id}"
    )
    nil
  end

  private
    attr_reader :share, :request

    def ip_address
      request.remote_ip.to_s.first(IP_ADDRESS_LIMIT)
    end

    def user_agent
      request.user_agent.to_s.first(USER_AGENT_LIMIT)
    end
end
