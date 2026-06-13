require "digest"

class PublicBeanShareViewRecorder
  IP_ADDRESS_LIMIT = 255
  USER_AGENT_LIMIT = 512

  def initialize(share:, request:)
    @share = share
    @request = request
  end

  def call
    PublicBeanShareView.create!(
      public_bean_share: share,
      workspace: share.workspace,
      ip_address: ip_address,
      user_agent: user_agent.presence,
      viewed_at: Time.current
    )
  rescue StandardError => error
    Rails.logger.info(
      "PublicBeanShareViewRecorder failed " \
        "exception_class=#{error.class.name} " \
        "public_bean_share_id_digest=#{share_id_digest}"
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

    def share_id_digest
      Digest::SHA256.hexdigest(share.id.to_s).first(12)
    end
end
