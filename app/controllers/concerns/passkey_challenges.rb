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
      return unless passkey_challenge_user_matches?(payload, user_id)

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

      User.find_by(id: user_id) || clear_pending_passkey_user
    rescue ArgumentError, TypeError
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

    def passkey_challenge_user_matches?(payload, user_id)
      stored_user_id = payload["user_id"]
      return true if stored_user_id.blank? && user_id.blank?
      return false if stored_user_id.blank? || user_id.blank?

      stored_user_id.to_i == user_id.to_i
    end
end
